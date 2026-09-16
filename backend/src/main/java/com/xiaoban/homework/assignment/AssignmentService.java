package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.storage.FileStorage;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.submission.SubmissionEntity;
import com.xiaoban.homework.submission.SubmissionPhotoEntity;
import com.xiaoban.homework.submission.SubmissionPhotoRepository;
import com.xiaoban.homework.submission.SubmissionRepository;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AssignmentService {
  private static final String DEFAULT_ASSIGNMENT_TYPE = "SCHOOL";
  private static final String DEFAULT_SUBJECT_CODE = "OTHER";
  private static final String DEFAULT_DUE_TIMEZONE = "Asia/Shanghai";

  private final AssignmentRepository repository;
  private final StudentService students;
  private final SubmissionRepository submissions;
  private final SubmissionPhotoRepository photos;
  private final FileStorage storage;

  public AssignmentService(AssignmentRepository repository, StudentService students,
      SubmissionRepository submissions, SubmissionPhotoRepository photos, FileStorage storage) {
    this.repository = repository;
    this.students = students;
    this.submissions = submissions;
    this.photos = photos;
    this.storage = storage;
  }

  @Transactional(readOnly = true)
  public List<AssignmentDtos.Response> list(UUID familyId, String studentId) {
    students.requireOwned(familyId, studentId);
    return repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId).stream()
        .map(AssignmentDtos.Response::from).toList();
  }

  @Transactional(readOnly = true)
  public AssignmentDtos.TodaySummary todaySummary(UUID familyId, String studentId, LocalDate date) {
    students.requireOwned(familyId, studentId);
    List<AssignmentEntity> assignments = repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId);
    int total = 0;
    int completed = 0;
    int attention = 0;
    int undated = 0;
    AssignmentEntity next = null;

    for (AssignmentEntity assignment : assignments) {
      if (assignment.dueAt == null) {
        if (!"COMPLETED".equals(assignment.status)) undated++;
      } else if (isOnDate(assignment, date)) {
        total++;
        if ("COMPLETED".equals(assignment.status)) completed++;
      }
      if ("NEEDS_REWORK".equals(assignment.status) || "OVERDUE".equals(assignment.status)) attention++;
      if (isBetterNext(assignment, next)) next = assignment;
    }

    return new AssignmentDtos.TodaySummary(total, completed, attention, undated, next == null ? "" : next.id);
  }

  @Transactional
  public AssignmentDtos.Response create(UUID familyId, String studentId, AssignmentDtos.Create input) {
    students.requireOwned(familyId, studentId);
    AssignmentEntity existing = repository.findById(input.id()).orElse(null);
    if (existing != null) {
      if (!familyId.equals(existing.familyId) || !studentId.equals(existing.studentId)) {
        throw new ApiExceptions.Conflict("作业 ID 冲突");
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
    e.title = input.title();
    e.instruction = input.instruction();
    e.textbookRef = text(input.textbookRef());
    e.dueText = text(input.dueText());
    e.dueAt = dueAt(input.dueAtEpochMs());
    e.dueTimezone = dueTimezone(input.dueTimezone());
    e.status = input.status();
    e.sourceLabel = text(input.sourceLabel());
    e.sourceExcerpt = text(input.sourceExcerpt());
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
    return AssignmentDtos.Response.from(repository.saveAndFlush(e));
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
    if (input.title() != null) e.title = input.title();
    if (input.instruction() != null) e.instruction = input.instruction();
    if (input.textbookRef() != null) e.textbookRef = input.textbookRef();
    if (input.dueText() != null) e.dueText = input.dueText();
    if (input.dueAtEpochMs() != null) e.dueAt = dueAt(input.dueAtEpochMs());
    if (input.dueTimezone() != null) e.dueTimezone = dueTimezone(input.dueTimezone());
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
    return AssignmentDtos.Response.from(repository.saveAndFlush(e));
  }

  @Transactional
  public void delete(UUID familyId, String id) {
    AssignmentEntity assignment = requireOwned(familyId, id);
    for (SubmissionEntity submission : submissions.findByFamilyIdAndAssignmentIdOrderBySubmittedAtDesc(familyId, id)) {
      for (SubmissionPhotoEntity photo : photos.findBySubmissionIdOrderById(submission.id)) {
        storage.delete(photo.storagePath);
      }
    }
    repository.delete(assignment);
    repository.flush();
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
    }
  }

  @Transactional(readOnly = true)
  public AssignmentEntity requireOwned(UUID familyId, String id) {
    AssignmentEntity e = repository.findById(id).orElseThrow(() -> new ApiExceptions.NotFound("作业不存在"));
    if (!familyId.equals(e.familyId)) throw new ApiExceptions.NotFound("作业不存在");
    return e;
  }

  private boolean isOnDate(AssignmentEntity assignment, LocalDate date) {
    try {
      ZoneId zone = ZoneId.of(dueTimezone(assignment.dueTimezone));
      return assignment.dueAt.atZone(zone).toLocalDate().equals(date);
    } catch (DateTimeException error) {
      return false;
    }
  }

  private boolean isBetterNext(AssignmentEntity candidate, AssignmentEntity current) {
    int candidatePriority = nextPriority(candidate.status);
    if (candidatePriority >= 100) return false;
    if (current == null) return true;
    int currentPriority = nextPriority(current.status);
    if (candidatePriority != currentPriority) return candidatePriority < currentPriority;
    if (candidate.dueAt != null && current.dueAt == null) return true;
    if (candidate.dueAt == null && current.dueAt != null) return false;
    if (candidate.dueAt != null && current.dueAt != null && !candidate.dueAt.equals(current.dueAt)) {
      return candidate.dueAt.isBefore(current.dueAt);
    }
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

  private String assignmentType(String value) {
    String normalized = value == null || value.isBlank() ? DEFAULT_ASSIGNMENT_TYPE : value.trim().toUpperCase();
    if (!"SCHOOL".equals(normalized) && !"EXTRA".equals(normalized)) {
      throw new ApiExceptions.BadRequest("不支持的作业类型: " + value);
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

  private Instant dueAt(Long value) {
    return value == null || value <= 0 ? null : Instant.ofEpochMilli(value);
  }

  private String dueTimezone(String value) {
    String normalized = value == null || value.isBlank() ? DEFAULT_DUE_TIMEZONE : value.trim();
    try {
      ZoneId.of(normalized);
      return normalized;
    } catch (DateTimeException error) {
      throw new ApiExceptions.BadRequest("无效的截止时间时区: " + normalized);
    }
  }

  private int expectedMinutes(Integer value) { return value == null ? 20 : Math.max(1, Math.min(240, value)); }
  private long nonNegative(Long value) { return value == null ? 0 : Math.max(0, value); }
  private String text(String value) { return value == null ? "" : value; }
}
