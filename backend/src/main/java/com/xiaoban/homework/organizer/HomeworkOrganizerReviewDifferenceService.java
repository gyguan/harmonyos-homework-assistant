package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeworkOrganizerReviewDifferenceService {
  private static final Set<String> FIELDS = Set.of(
      "title", "instruction", "subject", "taskDate", "expectedMinutes", "textbookRef", "task");
  private static final Set<String> TYPES = Set.of("CHANGED", "ADDED", "REMOVED");
  private final HomeworkOrganizerReviewDifferenceRepository repository;
  private final HomeworkStudentTeacherService teachers;
  private final HomeworkOrganizerAiSnapshotRepository snapshots;
  private final AssignmentRepository assignments;

  public HomeworkOrganizerReviewDifferenceService(
      HomeworkOrganizerReviewDifferenceRepository repository, HomeworkStudentTeacherService teachers) {
    this(repository, teachers, null, null);
  }

  @Autowired
  public HomeworkOrganizerReviewDifferenceService(
      HomeworkOrganizerReviewDifferenceRepository repository, HomeworkStudentTeacherService teachers,
      HomeworkOrganizerAiSnapshotRepository snapshots, AssignmentRepository assignments) {
    this.repository = repository;
    this.teachers = teachers;
    this.snapshots = snapshots;
    this.assignments = assignments;
  }
  public record Difference(@NotBlank @Size(max = 180) String candidateId,
      @NotBlank String changeType, @NotBlank String fieldName,
      @Size(max = 1500) String beforeValue, @Size(max = 1500) String afterValue,
      @Size(max = 500) String sourceExcerpt) {}
  public record Review(@NotBlank @Size(max = 180) String batchId,
      @Size(max = 80) String teacherName,
      @Size(min = 1, max = 150) List<@Valid Difference> differences) {}
  public record Result(int saved, int ignored) {}
  public record Finalize(@NotBlank @Size(max = 140) String batchId,
      @Size(min = 1, max = 50) List<@NotBlank @Size(max = 180) String> publishedCandidateIds) {}
  public record History(UUID id, String batchId, String teacherName, String candidateId,
      String changeType, String fieldName, String beforeValue, String afterValue, Instant createdAt) {
    static History from(HomeworkOrganizerReviewDifferenceEntity e) {
      return new History(e.id, e.batchId, e.teacherName, e.candidateId, e.changeType,
          e.fieldName, e.beforeValue, e.afterValue, e.createdAt);
    }
  }

  /**
   * Server-owned original snapshots are compared with the actual published assignment
   * records, never with client-submitted before/after values. The frontend only supplies
   * the candidate IDs acknowledged by its successful atomic publish.
   */
  @Transactional
  public Result finalizePublished(UUID familyId, String studentId, Finalize request) {
    teachers.requireOwned(familyId, studentId);
    if (snapshots == null || assignments == null) {
      throw new ApiExceptions.ServiceUnavailable("作业对比服务不可用");
    }
    if (request.publishedCandidateIds() == null || request.publishedCandidateIds().isEmpty()) {
      throw new ApiExceptions.BadRequest("缺少已发布的作业");
    }
    var originals = snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        familyId, studentId, request.batchId());
    if (originals.isEmpty()) {
      // Legacy imports have no authoritative snapshot. Do not invent any corrections.
      return new Result(0, 0);
    }
    String teacher = originals.getFirst().teacherName;
    java.util.Map<String, HomeworkOrganizerAiSnapshotEntity> originalById = new java.util.HashMap<>();
    for (var original : originals) {
      if (!original.teacherName.equals(teacher)) {
        throw new ApiExceptions.BadRequest("作业批次老师信息不一致");
      }
      originalById.put(original.candidateId, original);
    }
    java.util.Map<String, AssignmentEntity> published = new java.util.LinkedHashMap<>();
    for (String rawId : request.publishedCandidateIds()) {
      String id = rawId.trim();
      if (published.containsKey(id)) throw new ApiExceptions.BadRequest("同一任务不能重复发布");
      if (!originalById.containsKey(id) && !id.startsWith("manual-")) {
        throw new ApiExceptions.BadRequest("包含不属于 AI 初稿的任务");
      }
      var record = assignments.findById("a-published-" + id)
          .orElseThrow(() -> new ApiExceptions.BadRequest("未找到已发布的作业"));
      if (!familyId.equals(record.familyId) || !studentId.equals(record.studentId)) {
        throw new ApiExceptions.NotFound("孩子的作业不存在");
      }
      published.put(id, record);
    }
    List<Difference> changes = new java.util.ArrayList<>();
    for (var old : originals) {
      var result = published.get(old.candidateId);
      if (result == null) {
        changes.add(new Difference(old.candidateId, "REMOVED", "task",
            old.title, "", old.sourceExcerpt));
        continue;
      }
      append(changes, old.candidateId, "title", old.title, result.title, old.sourceExcerpt);
      append(changes, old.candidateId, "subject", old.subject, result.subject, old.sourceExcerpt);
      append(changes, old.candidateId, "instruction", old.instruction,
          result.instruction, old.sourceExcerpt);
      append(changes, old.candidateId, "textbookRef", old.textbookRef,
          result.textbookRef, old.sourceExcerpt);
      append(changes, old.candidateId, "taskDate", old.taskDate,
          result.taskDate == null ? "" : result.taskDate.toString(), old.sourceExcerpt);
      append(changes, old.candidateId, "expectedMinutes",
          String.valueOf(old.expectedMinutes), String.valueOf(result.expectedMinutes),
          old.sourceExcerpt);
    }
    for (var entry : published.entrySet()) {
      if (!originalById.containsKey(entry.getKey())) {
        changes.add(new Difference(entry.getKey(), "ADDED", "task",
            "", safe(entry.getValue().title), safe(entry.getValue().sourceExcerpt)));
      }
    }
    if (changes.isEmpty()) return new Result(0, 0);
    return save(familyId, studentId, new Review(request.batchId(), teacher, changes));
  }

  private static void append(List<Difference> changes, String id, String field,
      String before, String after, String source) {
    if (!safe(before).equals(safe(after))) {
      changes.add(new Difference(id, "CHANGED", field, safe(before), safe(after), safe(source)));
    }
  }
  private static String safe(String value) { return value == null ? "" : value.trim(); }

  @Transactional
  public Result save(UUID familyId, String studentId, Review request) {
    String teacher = teachers.verifiedTeacher(familyId, studentId, request.teacherName());
    int saved = 0;
    int ignored = 0;
    for (Difference change : request.differences()) {
      String type = change.changeType().trim();
      String field = change.fieldName().trim();
      if (!TYPES.contains(type) || !FIELDS.contains(field)
          || ("CHANGED".equals(type) && "task".equals(field))
          || (!"CHANGED".equals(type) && !"task".equals(field))) {
        throw new ApiExceptions.BadRequest("作业纠错差异类型不合法");
      }
      boolean exists = repository.existsByFamilyIdAndStudentIdAndBatchIdAndCandidateIdAndChangeTypeAndFieldName(
          familyId, studentId, request.batchId(), change.candidateId(), type, field);
      if (exists) {
        ignored++;
        continue;
      }
      var entity = new HomeworkOrganizerReviewDifferenceEntity();
      entity.id = UUID.randomUUID();
      entity.familyId = familyId;
      entity.studentId = studentId;
      entity.batchId = request.batchId();
      entity.candidateId = change.candidateId();
      entity.teacherName = teacher;
      entity.changeType = type;
      entity.fieldName = field;
      entity.beforeValue = change.beforeValue() == null ? "" : change.beforeValue();
      entity.afterValue = change.afterValue() == null ? "" : change.afterValue();
      entity.sourceExcerpt = change.sourceExcerpt() == null ? "" : change.sourceExcerpt();
      entity.createdAt = Instant.now();
      repository.save(entity);
      saved++;
    }
    return new Result(saved, ignored);
  }

  /** Recent correction distribution; not an accuracy percentage without verified ground truth. */
  public record Summary(String teacherName, String fieldName, String changeType, long count) {}

  @Transactional(readOnly = true)
  public List<Summary> summary(UUID familyId, String studentId) {
    teachers.requireOwned(familyId, studentId);
    var rows = repository.findTop100ByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, studentId);
    java.util.Map<String, Long> counts = new java.util.LinkedHashMap<>();
    for (var item : rows) {
      String key = item.teacherName + "\u001F" + item.fieldName + "\u001F" + item.changeType;
      counts.merge(key, 1L, Long::sum);
    }
    return counts.entrySet().stream().map(entry -> {
      String[] pieces = entry.getKey().split("\u001F", -1);
      return new Summary(pieces[0], pieces[1], pieces[2], entry.getValue());
    }).sorted(java.util.Comparator.comparingLong(Summary::count).reversed()).toList();
  }

  @Transactional(readOnly = true)
  public List<History> history(UUID familyId, String studentId) {
    teachers.requireOwned(familyId, studentId);
    return repository.findTop100ByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, studentId)
        .stream().map(History::from).toList();
  }
}
