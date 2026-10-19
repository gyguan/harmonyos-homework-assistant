package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
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
  public HomeworkOrganizerReviewDifferenceService(
      HomeworkOrganizerReviewDifferenceRepository repository, HomeworkStudentTeacherService teachers) {
    this.repository = repository;
    this.teachers = teachers;
  }
  public record Difference(@NotBlank @Size(max = 180) String candidateId,
      @NotBlank String changeType, @NotBlank String fieldName,
      @Size(max = 1500) String beforeValue, @Size(max = 1500) String afterValue,
      @Size(max = 500) String sourceExcerpt) {}
  public record Review(@NotBlank @Size(max = 180) String batchId,
      @Size(max = 80) String teacherName,
      @Size(min = 1, max = 150) List<@Valid Difference> differences) {}
  public record Result(int saved, int ignored) {}
  public record History(UUID id, String batchId, String teacherName, String candidateId,
      String changeType, String fieldName, String beforeValue, String afterValue, Instant createdAt) {
    static History from(HomeworkOrganizerReviewDifferenceEntity e) {
      return new History(e.id, e.batchId, e.teacherName, e.candidateId, e.changeType,
          e.fieldName, e.beforeValue, e.afterValue, e.createdAt);
    }
  }

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
