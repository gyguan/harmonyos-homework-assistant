package com.xiaoban.homework.coverage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.auth.AccountEntity;
import com.xiaoban.homework.auth.AccountRepository;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class DailyHomeworkCoverageServiceTest {
  static class TestStudent extends StudentEntity {
    TestStudent() { super(); }
  }

  @Test
  void allOverridesIndividualSubjects() {
    assertEquals(
        List.of("ALL"),
        DailyHomeworkCoverageService.normalize(List.of("MATH", "ALL", "CHINESE")));
    assertEquals(
        List.of("CHINESE", "MATH", "ENGLISH"),
        DailyHomeworkCoverageService.normalize(List.of("ENGLISH", "MATH", "CHINESE", "MATH")));
  }

  @Test
  void updateMineReplacesOnlyCurrentParentCoverage() {
    var repository = mock(DailyHomeworkCoverageRepository.class);
    var students = mock(StudentRepository.class);
    var accounts = mock(AccountRepository.class);
    var service = new DailyHomeworkCoverageService(repository, students, accounts);

    UUID familyId = UUID.randomUUID();
    UUID accountId = UUID.randomUUID();
    String studentId = "student-1";
    LocalDate date = LocalDate.now(ZoneId.of("Asia/Shanghai"));

    TestStudent student = new TestStudent();
    student.id = studentId;
    student.familyId = familyId;
    student.name = "小宇";
    when(students.findById(studentId)).thenReturn(Optional.of(student));

    AccountEntity account = new AccountEntity(
        accountId, familyId, "dad", "hash", "爸爸", Instant.now());
    when(accounts.findById(accountId)).thenReturn(Optional.of(account));
    when(repository.findByFamilyIdAndStudentIdAndTaskDateOrderByUpdatedAtDesc(
        familyId, studentId, date)).thenReturn(List.of());

    service.updateMine(
        familyId, accountId, studentId, date,
        new DailyHomeworkCoverageDtos.UpdateRequest(List.of("CHINESE", "MATH")));

    verify(repository).deleteByFamilyIdAndStudentIdAndTaskDateAndAccountId(
        familyId, studentId, date, accountId);
    verify(repository).flush();

    @SuppressWarnings("unchecked")
    ArgumentCaptor<Iterable<DailyHomeworkCoverageEntity>> captor =
        ArgumentCaptor.forClass(Iterable.class);
    verify(repository).saveAll(captor.capture());

    int count = 0;
    boolean chinese = false;
    boolean math = false;
    for (DailyHomeworkCoverageEntity entity : captor.getValue()) {
      count++;
      chinese = chinese || "CHINESE".equals(entity.subjectCode);
      math = math || "MATH".equals(entity.subjectCode);
      assertEquals(accountId, entity.accountId);
      assertEquals(familyId, entity.familyId);
      assertEquals(studentId, entity.studentId);
      assertEquals(date, entity.taskDate);
    }
    assertEquals(2, count);
    assertTrue(chinese);
    assertTrue(math);
  }

  @Test
  void currentParentIsMarkedAndReturnedBeforeOtherParents() {
    var repository = mock(DailyHomeworkCoverageRepository.class);
    var students = mock(StudentRepository.class);
    var accounts = mock(AccountRepository.class);
    var service = new DailyHomeworkCoverageService(repository, students, accounts);

    UUID familyId = UUID.randomUUID();
    UUID dadId = UUID.randomUUID();
    UUID momId = UUID.randomUUID();
    LocalDate date = LocalDate.of(2026, 10, 13);

    TestStudent student = new TestStudent();
    student.id = "student-1";
    student.familyId = familyId;
    student.name = "小宇";
    when(students.findById("student-1")).thenReturn(Optional.of(student));

    DailyHomeworkCoverageEntity dad = row(
        familyId, student.id, date, dadId, "MATH", Instant.parse("2026-10-13T08:00:00Z"));
    DailyHomeworkCoverageEntity mom = row(
        familyId, student.id, date, momId, "ENGLISH", Instant.parse("2026-10-13T09:00:00Z"));
    when(repository.findByFamilyIdAndStudentIdAndTaskDateOrderByUpdatedAtDesc(
        familyId, student.id, date)).thenReturn(List.of(mom, dad));

    AccountEntity dadAccount = new AccountEntity(
        dadId, familyId, "dad", "hash", "爸爸", Instant.now());
    AccountEntity momAccount = new AccountEntity(
        momId, familyId, "mom", "hash", "妈妈", Instant.now());
    when(accounts.findAllById(any())).thenReturn(List.of(dadAccount, momAccount));

    var response = service.get(familyId, dadId, student.id, date);

    assertEquals("爸爸", response.parents().getFirst().displayName());
    assertTrue(response.parents().getFirst().mine());
    assertEquals(List.of("MATH"), response.parents().getFirst().subjects());
    assertEquals("妈妈", response.parents().get(1).displayName());
  }

  private static DailyHomeworkCoverageEntity row(
      UUID familyId, String studentId, LocalDate date, UUID accountId, String subject, Instant updatedAt) {
    DailyHomeworkCoverageEntity entity = new DailyHomeworkCoverageEntity();
    entity.id = UUID.randomUUID();
    entity.familyId = familyId;
    entity.studentId = studentId;
    entity.taskDate = date;
    entity.accountId = accountId;
    entity.subjectCode = subject;
    entity.createdAt = updatedAt;
    entity.updatedAt = updatedAt;
    return entity;
  }
}
