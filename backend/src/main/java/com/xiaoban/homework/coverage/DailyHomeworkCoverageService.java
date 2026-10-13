package com.xiaoban.homework.coverage;

import com.xiaoban.homework.auth.AccountEntity;
import com.xiaoban.homework.auth.AccountRepository;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DailyHomeworkCoverageService {
  private static final Set<String> ALLOWED =
      Set.of("ALL", "CHINESE", "MATH", "ENGLISH");

  private final DailyHomeworkCoverageRepository coverage;
  private final StudentRepository students;
  private final AccountRepository accounts;

  public DailyHomeworkCoverageService(
      DailyHomeworkCoverageRepository coverage,
      StudentRepository students,
      AccountRepository accounts) {
    this.coverage = coverage;
    this.students = students;
    this.accounts = accounts;
  }

  @Transactional(readOnly = true)
  public DailyHomeworkCoverageDtos.Response get(
      UUID familyId, UUID accountId, String studentId, LocalDate taskDate) {
    StudentEntity student = requireStudent(familyId, studentId);
    List<DailyHomeworkCoverageEntity> rows =
        coverage.findByFamilyIdAndStudentIdAndTaskDateOrderByUpdatedAtDesc(
            familyId, studentId, taskDate);

    Map<UUID, List<DailyHomeworkCoverageEntity>> byAccount = new LinkedHashMap<>();
    for (DailyHomeworkCoverageEntity row : rows) {
      byAccount.computeIfAbsent(row.accountId, ignored -> new ArrayList<>()).add(row);
    }

    Map<UUID, String> displayNames = new LinkedHashMap<>();
    for (AccountEntity account : accounts.findAllById(byAccount.keySet())) {
      if (familyId.equals(account.familyId)) {
        displayNames.put(account.id, account.displayName);
      }
    }

    List<DailyHomeworkCoverageDtos.ParentCoverage> parents = new ArrayList<>();
    for (Map.Entry<UUID, List<DailyHomeworkCoverageEntity>> entry : byAccount.entrySet()) {
      List<DailyHomeworkCoverageEntity> accountRows = entry.getValue();
      List<String> subjects = new ArrayList<>();
      Instant updatedAt = Instant.EPOCH;
      for (DailyHomeworkCoverageEntity row : accountRows) {
        subjects.add(row.subjectCode);
        if (row.updatedAt != null && row.updatedAt.isAfter(updatedAt)) updatedAt = row.updatedAt;
      }
      subjects.sort(Comparator.comparingInt(DailyHomeworkCoverageService::subjectOrder));
      String displayName = displayNames.getOrDefault(entry.getKey(), "家庭成员");
      parents.add(new DailyHomeworkCoverageDtos.ParentCoverage(
          displayName, accountId.equals(entry.getKey()), List.copyOf(subjects), updatedAt));
    }
    parents.sort(Comparator
        .comparing(DailyHomeworkCoverageDtos.ParentCoverage::mine).reversed()
        .thenComparing(DailyHomeworkCoverageDtos.ParentCoverage::updatedAt).reversed());

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
    AccountEntity account = accounts.findById(accountId)
        .orElseThrow(() -> new ApiExceptions.Unauthorized("登录状态已失效，请重新登录"));
    if (!familyId.equals(account.familyId)) {
      throw new ApiExceptions.Unauthorized("登录状态无效");
    }

    List<String> normalized = normalize(input.subjects());
    coverage.deleteByFamilyIdAndStudentIdAndTaskDateAndAccountId(
        familyId, studentId, taskDate, accountId);

    Instant now = Instant.now();
    List<DailyHomeworkCoverageEntity> created = new ArrayList<>();
    for (String subject : normalized) {
      DailyHomeworkCoverageEntity entity = new DailyHomeworkCoverageEntity();
      entity.id = UUID.randomUUID();
      entity.familyId = familyId;
      entity.studentId = studentId;
      entity.taskDate = taskDate;
      entity.accountId = accountId;
      entity.subjectCode = subject;
      entity.createdAt = now;
      entity.updatedAt = now;
      created.add(entity);
    }
    if (!created.isEmpty()) coverage.saveAll(created);
    return get(familyId, accountId, studentId, taskDate);
  }

  private StudentEntity requireStudent(UUID familyId, String studentId) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    return student;
  }

  static List<String> normalize(List<String> subjects) {
    if (subjects == null || subjects.isEmpty()) return List.of();
    LinkedHashSet<String> result = new LinkedHashSet<>();
    for (String raw : subjects) {
      String value = raw == null ? "" : raw.trim().toUpperCase();
      if (!ALLOWED.contains(value)) {
        throw new ApiExceptions.BadRequest("不支持的作业协同科目: " + value);
      }
      result.add(value);
    }
    if (result.contains("ALL")) return List.of("ALL");
    List<String> ordered = new ArrayList<>(result);
    ordered.sort(Comparator.comparingInt(DailyHomeworkCoverageService::subjectOrder));
    return List.copyOf(ordered);
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
