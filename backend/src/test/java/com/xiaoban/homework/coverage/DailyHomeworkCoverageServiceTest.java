package com.xiaoban.homework.coverage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

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
  void parentIdentityIsLimitedToDadAndMom() {
    assertEquals("DAD", DailyHomeworkCoverageService.normalizeParentIdentity("dad"));
    assertEquals("MOM", DailyHomeworkCoverageService.normalizeParentIdentity(" MOM "));
  }

  @Test
  void updateReplacesOnlySelectedParentIdentity() {
    var repository = mock(DailyHomeworkCoverageRepository.class);
    var students = mock(StudentRepository.class);
    var service = new DailyHomeworkCoverageService(repository, students);

    UUID familyId = UUID.randomUUID();
    UUID accountId = UUID.randomUUID();
    String studentId = "student-1";
    LocalDate date = LocalDate.now(ZoneId.of("Asia/Shanghai"));

    TestStudent student = new TestStudent();
    student.id = studentId;
    student.familyId = familyId;
    student.name = "小宇";
    when(students.findById(studentId)).thenReturn(Optional.of(student));
    when(repository.findByFamilyIdAndStudentIdAndTaskDateOrderByUpdatedAtDesc(
        familyId, studentId, date)).thenReturn(List.of());

    service.updateMine(
        familyId, accountId, studentId, date,
        new DailyHomeworkCoverageDtos.UpdateRequest("DAD", List.of("CHINESE", "MATH")));

    verify(repository).deleteByFamilyIdAndStudentIdAndTaskDateAndParentIdentity(
        familyId, studentId, date, "DAD");
    verify(repository).flush();

    @SuppressWarnings("unchecked")
    ArgumentCaptor<Iterable<DailyHomeworkCoverageEntity>> captor =
        ArgumentCaptor.forClass(Iterable.class);
    verify(repository).saveAll(captor.capture());

    int count = 0;
    for (DailyHomeworkCoverageEntity entity : captor.getValue()) {
      count++;
      assertEquals(accountId, entity.accountId);
      assertEquals(familyId, entity.familyId);
      assertEquals(studentId, entity.studentId);
      assertEquals(date, entity.taskDate);
      assertEquals("DAD", entity.parentIdentity);
    }
    assertEquals(2, count);
  }

  @Test
  void responseAlwaysShowsDadAndMomAndMarksCurrentIdentity() {
    var repository = mock(DailyHomeworkCoverageRepository.class);
    var students = mock(StudentRepository.class);
    var service = new DailyHomeworkCoverageService(repository, students);

    UUID familyId = UUID.randomUUID();
    LocalDate date = LocalDate.of(2026, 10, 13);

    TestStudent student = new TestStudent();
    student.id = "student-1";
    student.familyId = familyId;
    student.name = "小宇";
    when(students.findById("student-1")).thenReturn(Optional.of(student));

    DailyHomeworkCoverageEntity dad = row(
        familyId, student.id, date, UUID.randomUUID(), "DAD", "MATH",
        Instant.parse("2026-10-13T08:00:00Z"));
    when(repository.findByFamilyIdAndStudentIdAndTaskDateOrderByUpdatedAtDesc(
        familyId, student.id, date)).thenReturn(List.of(dad));

    var response = service.get(familyId, "MOM", student.id, date);

    assertEquals(2, response.parents().size());
    assertEquals("MOM", response.parents().getFirst().parentIdentity());
    assertEquals("妈妈", response.parents().getFirst().displayName());
    assertTrue(response.parents().getFirst().mine());
    assertTrue(response.parents().getFirst().subjects().isEmpty());

    assertEquals("DAD", response.parents().get(1).parentIdentity());
    assertEquals("爸爸", response.parents().get(1).displayName());
    assertFalse(response.parents().get(1).mine());
    assertEquals(List.of("MATH"), response.parents().get(1).subjects());
  }

  private static DailyHomeworkCoverageEntity row(
      UUID familyId,
      String studentId,
      LocalDate date,
      UUID accountId,
      String parentIdentity,
      String subject,
      Instant updatedAt) {
    DailyHomeworkCoverageEntity entity = new DailyHomeworkCoverageEntity();
    entity.id = UUID.randomUUID();
    entity.familyId = familyId;
    entity.studentId = studentId;
    entity.taskDate = date;
    entity.accountId = accountId;
    entity.parentIdentity = parentIdentity;
    entity.subjectCode = subject;
    entity.createdAt = updatedAt;
    entity.updatedAt = updatedAt;
    return entity;
  }
}
