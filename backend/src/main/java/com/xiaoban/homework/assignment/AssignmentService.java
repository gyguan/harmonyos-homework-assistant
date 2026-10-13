package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.storage.FileTransactionCoordinator;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.submission.SubmissionEntity;
import com.xiaoban.homework.submission.SubmissionPhotoEntity;
import com.xiaoban.homework.submission.SubmissionPhotoRepository;
import com.xiaoban.homework.submission.SubmissionRepository;
import com.xiaoban.homework.submission.SubmissionResourceEntity;
import com.xiaoban.homework.submission.SubmissionResourceRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import jakarta.persistence.criteria.Predicate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AssignmentService {
  private static final Logger log = LoggerFactory.getLogger(AssignmentService.class);
  private static final String DEFAULT_ASSIGNMENT_TYPE = "SCHOOL";
  private static final String DEFAULT_SUBJECT_CODE = "OTHER";
  private static final String DEFAULT_CONTENT_TYPE = "NORMAL";
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");

  private final AssignmentRepository repository;
  private final StudentService students;
  private final SubmissionRepository submissions;
  private final SubmissionPhotoRepository photos;
  private final SubmissionResourceRepository submissionResources;
  private final AssignmentResourceRepository resources;
  private final FileTransactionCoordinator fileTransactions;

  public AssignmentService(AssignmentRepository repository, StudentService students,
      SubmissionRepository submissions, SubmissionPhotoRepository photos,
      SubmissionResourceRepository submissionResources,
      AssignmentResourceRepository resources, FileTransactionCoordinator fileTransactions) {
    this.repository = repository;
    this.students = students;
    this.submissions = submissions;
    this.photos = photos;
    this.submissionResources = submissionResources;
    this.resources = resources;
    this.fileTransactions = fileTransactions;
  }

  @Transactional(readOnly = true)
  public List<AssignmentDtos.Response> list(UUID familyId, String studentId) {
    return list(familyId, studentId, null, null, null, null, null);
  }

  @Transactional(readOnly = true)
  public AssignmentDtos.Response get(UUID familyId, String id) {
    return AssignmentDtos.Response.from(requireOwned(familyId, id));
  }

  @Transactional(readOnly = true)
  public List<AssignmentDtos.Response> list(UUID familyId, String studentId, String type, String subjectCode,
      Long fromEpochMs, Long toEpochMs, String status) {
    students.requireOwned(familyId, studentId);
    ListFilters filters = listFilters(type, subjectCode, fromEpochMs, toEpochMs, status);
    List<AssignmentEntity> filtered = repository.findAll(listSpecification(familyId, studentId, filters));
    filtered.sort(this::compareForList);
    return filtered.stream().map(AssignmentDtos.Response::from).toList();
  }

  @Transactional(readOnly = true)
  public AssignmentDtos.PageResponse page(UUID familyId, String studentId, String type, String subjectCode,
      Long fromEpochMs, Long toEpochMs, String status, int page, int limit) {
    students.requireOwned(familyId, studentId);
    if (page < 0) throw new ApiExceptions.BadRequest("page 不能小于 0");
    if (limit < 1 || limit > 100) throw new ApiExceptions.BadRequest("limit 必须在 1 到 100 之间");

    ListFilters filters = listFilters(type, subjectCode, fromEpochMs, toEpochMs, status);
    PageRequest pageable = PageRequest.of(page, limit,
        Sort.by(Sort.Order.desc("updatedAt"), Sort.Order.asc("id")));
    Page<AssignmentEntity> result = repository.findAll(listSpecification(familyId, studentId, filters), pageable);
    return new AssignmentDtos.PageResponse(
        result.getContent().stream().map(AssignmentDtos.Response::from).toList(),
        page, limit, result.hasNext(), result.getTotalElements());
  }

  @Transactional(readOnly = true)
  public AssignmentDtos.TodaySummary todaySummary(UUID familyId, String studentId, LocalDate date) {
    students.requireOwned(familyId, studentId);
    List<AssignmentEntity> assignments = repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId);
    int total = 0;
    int completed = 0;
    int attention = 0;
    AssignmentEntity next = null;

    for (AssignmentEntity assignment : assignments) {
      if (assignment.taskDate.equals(date)) {
        total++;
        if ("COMPLETED".equals(assignment.status)) completed++;
      }
      if ("NEEDS_REWORK".equals(assignment.status) ||
          (assignment.taskDate.isBefore(date) && !"COMPLETED".equals(assignment.status) &&
              !"SUBMITTED".equals(assignment.status))) attention++;
      if (isBetterNext(assignment, next)) next = assignment;
    }

    return new AssignmentDtos.TodaySummary(total, completed, attention, next == null ? "" : next.id);
  }

  @Transactional(readOnly = true)
  public String nextVoiceMaterialTaskTitle(UUID familyId, String studentId, String subjectCode,
      LocalDate businessDate, String materialTitle) {
    students.requireOwned(familyId, studentId);
    ZoneId zone = BUSINESS_ZONE;
    Instant from = businessDate.atStartOfDay(zone).toInstant();
    Instant to = businessDate.plusDays(1).atStartOfDay(zone).toInstant();
    String dateLabel = businessDate.getMonthValue() + "月" + businessDate.getDayOfMonth() + "日";
    String normalizedMaterialTitle = text(materialTitle).trim();
    String base = normalizedMaterialTitle.isBlank()
        ? subjectDisplay(subjectCode) + " · " + dateLabel + "语音作业"
        : subjectDisplay(subjectCode) + " · " + dateLabel + " · " + normalizedMaterialTitle;
    long count = repository
        .countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            familyId, studentId, subjectCode, "AUDIO_IMAGE", base, from, to);
    return count == 0 ? base : base + " " + toCircledNumber(count + 1);
  }

  private String toCircledNumber(long number) {
    if (number >= 2 && number <= 20) return String.valueOf((char) (0x2460 + number - 1));
    return "(" + number + ")";
  }

  private String subjectDisplay(String subjectCode) {
    return switch (subjectCode) {
      case "CHINESE" -> "语文";
      case "MATH" -> "数学";
      case "ENGLISH" -> "英语";
      default -> "其他";
    };
  }

  @Transactional(readOnly = true)
  public AssignmentDtos.Response findFirstVoiceMaterialTask(UUID familyId, String studentId) {
    students.requireOwned(familyId, studentId);
    AssignmentEntity current = repository
        .findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotOrderByUpdatedAtDesc(
            familyId, studentId, "AUDIO_IMAGE", "COMPLETED")
        .orElse(null);
    return current == null ? null : AssignmentDtos.Response.from(current);
  }

  @Transactional(readOnly = true)
  public AssignmentDtos.Response findFirstVoiceMaterialTaskForDate(
      UUID familyId, String studentId, LocalDate businessDate) {
    students.requireOwned(familyId, studentId);
    AssignmentEntity current = repository
        .findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotAndTaskDateOrderByUpdatedAtDesc(
            familyId, studentId, "AUDIO_IMAGE", "COMPLETED", businessDate)
        .orElse(null);
    return current == null ? null : AssignmentDtos.Response.from(current);
  }

  @Transactional
  public AssignmentDtos.Response create(UUID familyId, String studentId, AssignmentDtos.Create input) {
    students.requireOwned(familyId, studentId);
    LocalDate effectiveTaskDate = createTaskDate(input.taskDate());
    String createFingerprint = createFingerprint(studentId, input, effectiveTaskDate);
    AssignmentEntity existing = repository.findById(input.id()).orElse(null);
    if (existing != null) {
      if (!familyId.equals(existing.familyId) || !studentId.equals(existing.studentId)) {
        throw new ApiExceptions.Conflict("作业 ID 冲突");
      }
      if (existing.createFingerprint != null && !existing.createFingerprint.isBlank() &&
          !existing.createFingerprint.equals(createFingerprint)) {
        throw new ApiExceptions.Conflict("作业 ID 已存在，但创建内容与原请求不一致");
      }
      return AssignmentDtos.Response.from(existing);
    }
    AssignmentEntity e = new AssignmentEntity();
    Instant now = Instant.now();
    long nowMs = System.currentTimeMillis();
    e.id = input.id();
    e.familyId = familyId;
    e.studentId = studentId;
    e.assignmentType = assignmentType(input.assignmentType());
    e.subject = input.subject();
    e.subjectCode = subjectCode(input.subjectCode(), input.subject());
    e.contentType = contentType(input.contentType());
    e.title = input.title();
    e.instruction = input.instruction();
    e.textbookRef = text(input.textbookRef());
    e.taskDate = effectiveTaskDate;
    e.status = initialStatus(input.status());
    e.sourceLabel = text(input.sourceLabel());
    e.sourceExcerpt = text(input.sourceExcerpt());
    e.createFingerprint = createFingerprint;
    e.expectedMinutes = expectedMinutes(input.expectedMinutes());
    e.startedAtEpochMs = nonNegative(input.startedAtEpochMs());
    e.finishedAtEpochMs = nonNegative(input.finishedAtEpochMs());
    e.elapsedSeconds = nonNegative(input.elapsedSeconds());
    e.reviewNote = text(input.reviewNote());
    if ("IN_PROGRESS".equals(e.status)) {
      pauseOtherActive(familyId, studentId, e.id, nowMs);
      if (e.startedAtEpochMs == 0) e.startedAtEpochMs = nowMs;
      e.finishedAtEpochMs = 0;
    }
    if ("PAUSED".equals(e.status)) {
      e.startedAtEpochMs = 0;
      e.finishedAtEpochMs = 0;
    }
    e.createdAt = now;
    e.updatedAt = now;
    AssignmentEntity saved = repository.saveAndFlush(e);
    log.info("assignment created assignmentId={} studentId={} assignmentType={} contentType={} subjectCode={} status={}",
        saved.id, saved.studentId, saved.assignmentType, saved.contentType, saved.subjectCode, saved.status);
    return AssignmentDtos.Response.from(saved);
  }

  @Transactional
  public AssignmentDtos.Response update(UUID familyId, String id, AssignmentDtos.Update input) {
    AssignmentEntity e = requireOwned(familyId, id);
    if (e.version != input.version()) throw new ApiExceptions.Conflict("作业已在其他设备更新，请刷新后重试");
    String previousStatus = e.status;
    long previousStartedAt = e.startedAtEpochMs;
    long previousElapsed = e.elapsedSeconds;
    if (input.status() != null && !AssignmentStatePolicy.canTransition(e.status, input.status())) {
      throw new ApiExceptions.BadRequest("不允许的作业状态流转: " + e.status + " -> " + input.status());
    }
    if (input.assignmentType() != null) e.assignmentType = assignmentType(input.assignmentType());
    if (input.subject() != null) {
      e.subject = input.subject();
      if (input.subjectCode() == null) e.subjectCode = subjectCode(null, input.subject());
    }
    if (input.subjectCode() != null) e.subjectCode = subjectCode(input.subjectCode(), e.subject);
    if (input.contentType() != null) e.contentType = contentType(input.contentType());
    if (input.title() != null) e.title = input.title();
    if (input.instruction() != null) e.instruction = input.instruction();
    if (input.textbookRef() != null) e.textbookRef = input.textbookRef();
    if (input.taskDate() != null) e.taskDate = taskDate(input.taskDate());
    if (input.status() != null) e.status = input.status();
    if (input.sourceLabel() != null) e.sourceLabel = input.sourceLabel();
    if (input.sourceExcerpt() != null) e.sourceExcerpt = input.sourceExcerpt();
    if (input.expectedMinutes() != null) e.expectedMinutes = expectedMinutes(input.expectedMinutes());
    if (input.startedAtEpochMs() != null) e.startedAtEpochMs = nonNegative(input.startedAtEpochMs());
    if (input.finishedAtEpochMs() != null) e.finishedAtEpochMs = nonNegative(input.finishedAtEpochMs());
    if (input.elapsedSeconds() != null) e.elapsedSeconds = nonNegative(input.elapsedSeconds());
    if (input.reviewNote() != null) e.reviewNote = input.reviewNote();

    long nowMs = System.currentTimeMillis();
    if (!"IN_PROGRESS".equals(previousStatus) && "IN_PROGRESS".equals(e.status)) {
      if (!"PAUSED".equals(previousStatus) && input.elapsedSeconds() == null) e.elapsedSeconds = 0;
      if (e.startedAtEpochMs == 0) e.startedAtEpochMs = nowMs;
      e.finishedAtEpochMs = 0;
      pauseOtherActive(familyId, e.studentId, e.id, nowMs);
    } else if ("IN_PROGRESS".equals(e.status)) {
      pauseOtherActive(familyId, e.studentId, e.id, nowMs);
    }

    if ("IN_PROGRESS".equals(previousStatus) && !"IN_PROGRESS".equals(e.status)) {
      if (input.elapsedSeconds() == null && previousStartedAt > 0) {
        e.elapsedSeconds = previousElapsed + Math.max(0, (nowMs - previousStartedAt) / 1000);
      }
      e.startedAtEpochMs = 0;
      if ("PAUSED".equals(e.status)) {
        e.finishedAtEpochMs = 0;
      } else if (e.finishedAtEpochMs == 0) {
        e.finishedAtEpochMs = nowMs;
      }
    }
    e.updatedAt = Instant.now();
    AssignmentEntity saved = repository.saveAndFlush(e);
    if (!previousStatus.equals(saved.status)) {
      log.info("assignment state_changed assignmentId={} studentId={} action=UPDATE from={} to={}",
          saved.id, saved.studentId, previousStatus, saved.status);
    }
    return AssignmentDtos.Response.from(saved);
  }

  @Transactional
  public AssignmentDtos.Response updateDetails(UUID familyId, String id, AssignmentDtos.DetailsUpdate input) {
    AssignmentEntity e = requireOwned(familyId, id);
    if (e.version != input.version()) throw new ApiExceptions.Conflict("作业已在其他设备更新，请刷新后重试");
    if ("SUBMITTED".equals(e.status) || "COMPLETED".equals(e.status)) {
      throw new ApiExceptions.BadRequest("已提交或已完成的作业不能再修改任务内容");
    }

    e.title = input.title().trim();
    if (input.instruction() != null) e.instruction = input.instruction();
    if (input.textbookRef() != null) e.textbookRef = input.textbookRef();
    if (input.taskDate() != null) e.taskDate = taskDate(input.taskDate());
    if (input.expectedMinutes() != null) e.expectedMinutes = expectedMinutes(input.expectedMinutes());
    e.updatedAt = Instant.now();
    return AssignmentDtos.Response.from(repository.saveAndFlush(e));
  }

  @Transactional
  public AssignmentDtos.BatchSyncResponse syncBatch(UUID familyId, String studentId,
      AssignmentDtos.BatchSyncRequest input) {
    students.requireOwned(familyId, studentId);
    List<AssignmentDtos.BatchSyncResult> results = new ArrayList<>();
    for (AssignmentDtos.BatchSyncItem item : input.items()) {
      AssignmentEntity current = requireOwned(familyId, item.id());
      if (!studentId.equals(current.studentId)) throw new ApiExceptions.NotFound("作业不存在");
      if (current.version != item.assignment().version()) {
        results.add(new AssignmentDtos.BatchSyncResult(
            item.id(), false, AssignmentDtos.Response.from(current)));
        continue;
      }
      AssignmentDtos.Response updated = update(familyId, item.id(), item.assignment());
      results.add(new AssignmentDtos.BatchSyncResult(item.id(), true, updated));
    }
    return new AssignmentDtos.BatchSyncResponse(results.size(), results);
  }

  @Transactional
  public AssignmentDtos.Response action(UUID familyId, String id, AssignmentDtos.ActionRequest input) {
    AssignmentEntity e = requireOwned(familyId, id);
    if (e.version != input.version()) throw new ApiExceptions.Conflict("作业已在其他设备更新，请刷新后重试");

    String action = input.action().trim().toUpperCase();
    String previousStatus = e.status;
    long nowMs = System.currentTimeMillis();
    switch (action) {
      case "START" -> start(e, familyId, nowMs);
      case "PAUSE" -> pause(e, nowMs);
      case "READY_TO_SUBMIT" -> readyToSubmit(e, nowMs);
      default -> throw new ApiExceptions.BadRequest("不支持的作业动作: " + input.action());
    }
    e.updatedAt = Instant.now();
    AssignmentEntity saved = repository.saveAndFlush(e);
    if (!previousStatus.equals(saved.status)) {
      log.info("assignment state_changed assignmentId={} studentId={} action={} from={} to={}",
          saved.id, saved.studentId, action, previousStatus, saved.status);
    }
    return AssignmentDtos.Response.from(saved);
  }

  @Transactional
  public void delete(UUID familyId, String id) {
    AssignmentEntity assignment = requireOwned(familyId, id);
    if ("COMPLETED".equals(assignment.status)) {
      throw new ApiExceptions.BadRequest("已完成作业不能删除");
    }
    Set<String> submissionStoragePaths = new HashSet<>();
    for (SubmissionEntity submission : submissions.findByFamilyIdAndAssignmentIdOrderBySubmittedAtDesc(familyId, id)) {
      for (SubmissionResourceEntity submissionResource :
          submissionResources.findBySubmissionIdOrderBySortOrderAscIdAsc(submission.id)) {
        if (submissionResource.storagePath != null && !submissionResource.storagePath.isBlank()) {
          submissionStoragePaths.add(submissionResource.storagePath);
        }
      }
      // Legacy rows remain readable during the compatibility window. V26 migrates them into
      // submission_resource, so a Set prevents the same physical file from being scheduled twice.
      for (SubmissionPhotoEntity photo : photos.findBySubmissionIdOrderById(submission.id)) {
        if (photo.storagePath != null && !photo.storagePath.isBlank()) {
          submissionStoragePaths.add(photo.storagePath);
        }
      }
    }
    for (String storagePath : submissionStoragePaths) {
      fileTransactions.deleteAfterCommit(storagePath);
    }
    for (AssignmentResourceEntity resource : resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(familyId, id)) {
      if (resource.assetId == null && resource.storagePath != null && !resource.storagePath.isBlank()) {
        fileTransactions.deleteAfterCommit(resource.storagePath);
      }
    }
    resources.deleteByFamilyIdAndAssignmentId(familyId, id);
    repository.delete(assignment);
    repository.flush();
    log.info("assignment deleted assignmentId={} studentId={} status={} contentType={}",
        assignment.id, assignment.studentId, assignment.status, assignment.contentType);
  }

  private void start(AssignmentEntity e, UUID familyId, long nowMs) {
    if (!AssignmentStatePolicy.canTransition(e.status, "IN_PROGRESS")) {
      throw new ApiExceptions.BadRequest("当前作业状态不能开始或继续: " + e.status);
    }
    String previousStatus = e.status;
    if (!"IN_PROGRESS".equals(previousStatus)) {
      if (!"PAUSED".equals(previousStatus) && !"READY_TO_SUBMIT".equals(previousStatus)) e.elapsedSeconds = 0;
      e.status = "IN_PROGRESS";
      e.startedAtEpochMs = nowMs;
      e.finishedAtEpochMs = 0;
    } else if (e.startedAtEpochMs == 0) {
      e.startedAtEpochMs = nowMs;
    }
    pauseOtherActive(familyId, e.studentId, e.id, nowMs);
  }

  private void pause(AssignmentEntity e, long nowMs) {
    if (!AssignmentStatePolicy.canTransition(e.status, "PAUSED")) {
      throw new ApiExceptions.BadRequest("当前作业状态不能暂停: " + e.status);
    }
    if ("IN_PROGRESS".equals(e.status) && e.startedAtEpochMs > 0) {
      e.elapsedSeconds += Math.max(0, (nowMs - e.startedAtEpochMs) / 1000);
    }
    e.status = "PAUSED";
    e.startedAtEpochMs = 0;
    e.finishedAtEpochMs = 0;
  }

  private void readyToSubmit(AssignmentEntity e, long nowMs) {
    if (!AssignmentStatePolicy.canTransition(e.status, "READY_TO_SUBMIT")) {
      throw new ApiExceptions.BadRequest("当前作业状态不能进入待提交: " + e.status);
    }
    if ("IN_PROGRESS".equals(e.status) && e.startedAtEpochMs > 0) {
      e.elapsedSeconds += Math.max(0, (nowMs - e.startedAtEpochMs) / 1000);
    }
    e.status = "READY_TO_SUBMIT";
    e.startedAtEpochMs = 0;
    if (e.finishedAtEpochMs == 0) e.finishedAtEpochMs = nowMs;
  }

  private record ListFilters(String type, String subjectCode, LocalDate from, LocalDate to,
      Set<String> statuses) {}

  private ListFilters listFilters(String type, String subjectCode, Long fromEpochMs, Long toEpochMs,
      String status) {
    String normalizedType = type == null || type.isBlank() ? null : assignmentType(type);
    String normalizedSubject = subjectCode == null || subjectCode.isBlank() ? null : subjectCode.trim().toUpperCase();
    LocalDate from = epochDate(fromEpochMs);
    LocalDate to = epochDate(toEpochMs);
    if (from != null && to != null && from.isAfter(to)) {
      throw new ApiExceptions.BadRequest("任务日期筛选开始日期不能晚于结束日期");
    }
    return new ListFilters(normalizedType, normalizedSubject, from, to, statusFilter(status));
  }

  private Specification<AssignmentEntity> listSpecification(UUID familyId, String studentId, ListFilters filters) {
    return (root, query, builder) -> {
      List<Predicate> predicates = new ArrayList<>();
      predicates.add(builder.equal(root.get("familyId"), familyId));
      predicates.add(builder.equal(root.get("studentId"), studentId));
      if (filters.type() != null) predicates.add(builder.equal(root.get("assignmentType"), filters.type()));
      if (filters.subjectCode() != null) predicates.add(builder.equal(root.get("subjectCode"), filters.subjectCode()));
      if (filters.from() != null) predicates.add(builder.greaterThanOrEqualTo(root.get("taskDate"), filters.from()));
      if (filters.to() != null) predicates.add(builder.lessThanOrEqualTo(root.get("taskDate"), filters.to()));
      if (!filters.statuses().isEmpty()) predicates.add(root.get("status").in(filters.statuses()));
      return builder.and(predicates.toArray(Predicate[]::new));
    };
  }

  private int compareForList(AssignmentEntity left, AssignmentEntity right) {
    int leftPriority = listPriority(left.status);
    int rightPriority = listPriority(right.status);
    if (leftPriority != rightPriority) return Integer.compare(leftPriority, rightPriority);
    if (!left.taskDate.equals(right.taskDate)) return left.taskDate.compareTo(right.taskDate);
    int titleCompare = text(left.title).compareTo(text(right.title));
    if (titleCompare != 0) return titleCompare;
    return left.id.compareTo(right.id);
  }

  private Set<String> statusFilter(String value) {
    Set<String> result = new HashSet<>();
    if (value == null || value.isBlank()) return result;
    for (String raw : value.split(",")) {
      String normalized = raw.trim().toUpperCase();
      if (normalized.isEmpty()) continue;
      if (!isSupportedStatus(normalized)) throw new ApiExceptions.BadRequest("不支持的作业状态: " + raw);
      result.add(normalized);
    }
    return result;
  }

  private boolean isSupportedStatus(String status) {
    return switch (status) {
      case "NOT_STARTED", "IN_PROGRESS", "PAUSED", "READY_TO_SUBMIT", "SUBMITTED", "COMPLETED",
          "NEEDS_REWORK", "OVERDUE" -> true;
      default -> false;
    };
  }

  private void pauseOtherActive(UUID familyId, String studentId, String activeId, long nowMs) {
    for (AssignmentEntity other : repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId)) {
      if (other.id.equals(activeId) || !"IN_PROGRESS".equals(other.status)) continue;
      if (other.startedAtEpochMs > 0) {
        other.elapsedSeconds += Math.max(0, (nowMs - other.startedAtEpochMs) / 1000);
      }
      other.startedAtEpochMs = 0;
      other.finishedAtEpochMs = 0;
      other.status = "PAUSED";
      other.updatedAt = Instant.now();
      repository.save(other);
      log.info("assignment auto_paused assignmentId={} studentId={} triggeredBy={} reason=ANOTHER_ASSIGNMENT_STARTED",
          other.id, studentId, activeId);
    }
  }

  @Transactional(readOnly = true)
  public AssignmentEntity requireOwned(UUID familyId, String id) {
    AssignmentEntity e = repository.findById(id).orElseThrow(() -> new ApiExceptions.NotFound("作业不存在"));
    if (!familyId.equals(e.familyId)) throw new ApiExceptions.NotFound("作业不存在");
    return e;
  }

  private boolean isBetterNext(AssignmentEntity candidate, AssignmentEntity current) {
    int candidatePriority = nextPriority(candidate.status);
    if (candidatePriority >= 100) return false;
    if (current == null) return true;
    int currentPriority = nextPriority(current.status);
    if (candidatePriority != currentPriority) return candidatePriority < currentPriority;
    if (!candidate.taskDate.equals(current.taskDate)) return candidate.taskDate.isBefore(current.taskDate);
    if (candidate.updatedAt == null) return false;
    return current.updatedAt == null || candidate.updatedAt.isAfter(current.updatedAt);
  }

  private int nextPriority(String status) {
    return switch (status) {
      case "IN_PROGRESS" -> 0;
      case "PAUSED" -> 1;
      case "NEEDS_REWORK" -> 2;
      case "OVERDUE" -> 3;
      case "NOT_STARTED" -> 4;
      case "READY_TO_SUBMIT" -> 5;
      default -> 100;
    };
  }

  private int listPriority(String status) {
    return switch (status) {
      case "IN_PROGRESS" -> 0;
      case "PAUSED" -> 1;
      case "NEEDS_REWORK" -> 2;
      case "OVERDUE" -> 3;
      case "READY_TO_SUBMIT" -> 4;
      case "NOT_STARTED" -> 5;
      case "SUBMITTED" -> 6;
      case "COMPLETED" -> 7;
      default -> 100;
    };
  }

  private String createFingerprint(
      String studentId, AssignmentDtos.Create input, LocalDate effectiveTaskDate) {
    String canonical = String.join("\n",
        text(studentId),
        assignmentType(input.assignmentType()),
        text(input.subject()),
        subjectCode(input.subjectCode(), input.subject()),
        contentType(input.contentType()),
        text(input.title()),
        text(input.instruction()),
        text(input.textbookRef()),
        effectiveTaskDate.toString(),
        initialStatus(input.status()),
        text(input.sourceLabel()),
        text(input.sourceExcerpt()),
        Integer.toString(expectedMinutes(input.expectedMinutes())));
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(digest.digest(canonical.getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException error) {
      throw new IllegalStateException("无法计算作业创建幂等指纹", error);
    }
  }

  private String initialStatus(String value) {
    String normalized = value == null ? "" : value.trim().toUpperCase();
    if (!"NOT_STARTED".equals(normalized)) {
      throw new ApiExceptions.BadRequest("新建作业初始状态必须为 NOT_STARTED");
    }
    return normalized;
  }

  private String assignmentType(String value) {
    String normalized = value == null || value.isBlank() ? DEFAULT_ASSIGNMENT_TYPE : value.trim().toUpperCase();
    if (!"SCHOOL".equals(normalized) && !"EXTRA".equals(normalized)) {
      throw new ApiExceptions.BadRequest("不支持的作业类型: " + value);
    }
    return normalized;
  }

  private String contentType(String value) {
    String normalized = value == null || value.isBlank() ? DEFAULT_CONTENT_TYPE : value.trim().toUpperCase();
    if (!"NORMAL".equals(normalized) && !"AUDIO_IMAGE".equals(normalized)) {
      throw new ApiExceptions.BadRequest("不支持的作业内容类型: " + value);
    }
    return normalized;
  }

  private String subjectCode(String value, String legacySubject) {
    if (value != null && !value.isBlank()) return value.trim().toUpperCase();
    if ("语文".equals(legacySubject)) return "CHINESE";
    if ("数学".equals(legacySubject)) return "MATH";
    if ("英语".equals(legacySubject)) return "ENGLISH";
    return DEFAULT_SUBJECT_CODE;
  }

  private LocalDate createTaskDate(String value) {
    if (value == null || value.isBlank()) return LocalDate.now(BUSINESS_ZONE);
    return taskDate(value);
  }

  private LocalDate taskDate(String value) {
    if (value == null || value.isBlank()) throw new ApiExceptions.BadRequest("任务日期不能为空");
    try {
      return LocalDate.parse(value.trim());
    } catch (java.time.format.DateTimeParseException error) {
      throw new ApiExceptions.BadRequest("任务日期格式应为 YYYY-MM-DD");
    }
  }

  private LocalDate epochDate(Long value) {
    if (value == null || value <= 0) return null;
    return Instant.ofEpochMilli(value).atZone(BUSINESS_ZONE).toLocalDate();
  }

  private int expectedMinutes(Integer value) { return value == null ? 20 : Math.max(1, Math.min(240, value)); }
  private long nonNegative(Long value) { return value == null ? 0 : Math.max(0, value); }
  private String text(String value) { return value == null ? "" : value; }
}
