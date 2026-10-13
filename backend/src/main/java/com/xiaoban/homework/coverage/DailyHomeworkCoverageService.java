package com.xiaoban.homework.coverage;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DailyHomeworkCoverageService {
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");
  private static final Set<String> ALLOWED_SUBJECTS =
      Set.of("ALL", "CHINESE", "MATH", "ENGLISH");
  private static final Set<String> ALLOWED_IDENTITIES = Set.of("DAD", "MOM");

  private final DailyHomeworkCoverageRepository coverage;
  private final StudentRepository students;

  public DailyHomeworkCoverageService(
      DailyHomeworkCoverageRepository coverage,
      StudentRepository students) {
    this.coverage = coverage;
    this.students = students;
  }

  @Transactional(readOnly = true)
  public DailyHomeworkCoverageDtos.Response get(
      UUID familyId, String currentParentIdentity, String studentId, LocalDate taskDate) {
    StudentEntity student = requireStudent(familyId, studentId);
    String current = normalizeParentIdentity(currentParentIdentity);
    List<DailyHomeworkCoverageEntity> rows =
        coverage.findByFamilyIdAndStudentIdAndTaskDateOrderByUpdatedAtDesc(
            familyId, studentId, taskDate);

    List<DailyHomeworkCoverageDtos.ParentCoverage> parents = new ArrayList<>();
    parents.add(parentCoverage("DAD", current, rows));
    parents.add(parentCoverage("MOM", current, rows));
    parents.sort(Comparator.comparing(
        (DailyHomeworkCoverageDtos.ParentCoverage item) -> !item.mine()));

    return new DailyHomeworkCoverageDtos.Response(
        studentId, student.name, taskDate, List.copyOf(parents));
  }

  @Transactional
  public DailyHomeworkCoverageDtos.Response updateMine(
      UUID familyId,
      UUID accountId,
      String studentId,
      LocalDate taskDate,
      DailyHomeworkCoverageDtos.UpdateRequest input) {
    requireStudent(familyId, studentId);
    if (!LocalDate.now(BUSINESS_ZONE).equals(taskDate)) {
      throw new ApiExceptions.BadRequest("只能修改今天的作业协同状态");
    }

    String parentIdentity = normalizeParentIdentity(input.parentIdentity());
    List<String> normalized = normalize(input.subjects());
    coverage.deleteByFamilyIdAndStudentIdAndTaskDateAndParentIdentity(
        familyId, studentId, taskDate, parentIdentity);
    coverage.flush();

    Instant now = Instant.now();
    List<DailyHomeworkCoverageEntity> created = new ArrayList<>();
    for (String subject : normalized) {
      DailyHomeworkCoverageEntity entity = new DailyHomeworkCoverageEntity();
      entity.id = UUID.randomUUID();
      entity.familyId = familyId;
      entity.studentId = studentId;
      entity.taskDate = taskDate;
      entity.accountId = accountId;
      entity.parentIdentity = parentIdentity;
      entity.subjectCode = subject;
      entity.createdAt = now;
      entity.updatedAt = now;
      created.add(entity);
    }
    if (!created.isEmpty()) coverage.saveAll(created);
    return get(familyId, parentIdentity, studentId, taskDate);
  }

  private DailyHomeworkCoverageDtos.ParentCoverage parentCoverage(
      String identity,
      String currentIdentity,
      List<DailyHomeworkCoverageEntity> rows) {
    List<String> subjects = new ArrayList<>();
    Instant updatedAt = null;
    for (DailyHomeworkCoverageEntity row : rows) {
      if (!identity.equals(row.parentIdentity)) continue;
      subjects.add(row.subjectCode);
      if (row.updatedAt != null && (updatedAt == null || row.updatedAt.isAfter(updatedAt))) {
        updatedAt = row.updatedAt;
      }
    }
    subjects.sort(Comparator.comparingInt(DailyHomeworkCoverageService::subjectOrder));
    return new DailyHomeworkCoverageDtos.ParentCoverage(
        identity,
        displayName(identity),
        identity.equals(currentIdentity),
        List.copyOf(subjects),
        updatedAt);
  }

  private StudentEntity requireStudent(UUID familyId, String studentId) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    return student;
  }

  static String normalizeParentIdentity(String value) {
    String normalized = value == null ? "" : value.trim().toUpperCase();
    if (!ALLOWED_IDENTITIES.contains(normalized)) {
      throw new ApiExceptions.BadRequest("不支持的家长身份");
    }
    return normalized;
  }

  static List<String> normalize(List<String> subjects) {
    if (subjects == null || subjects.isEmpty()) return List.of();
    LinkedHashSet<String> result = new LinkedHashSet<>();
    for (String raw : subjects) {
      String value = raw == null ? "" : raw.trim().toUpperCase();
      if (!ALLOWED_SUBJECTS.contains(value)) {
        throw new ApiExceptions.BadRequest("不支持的作业协同科目: " + value);
      }
      result.add(value);
    }
    if (result.contains("ALL")) return List.of("ALL");
    List<String> ordered = new ArrayList<>(result);
    ordered.sort(Comparator.comparingInt(DailyHomeworkCoverageService::subjectOrder));
    return List.copyOf(ordered);
  }

  private static String displayName(String identity) {
    return "MOM".equals(identity) ? "妈妈" : "爸爸";
  }

  private static int subjectOrder(String subject) {
    return switch (subject) {
      case "ALL" -> 0;
      case "CHINESE" -> 1;
      case "MATH" -> 2;
      case "ENGLISH" -> 3;
      default -> 99;
    };
  }
}
