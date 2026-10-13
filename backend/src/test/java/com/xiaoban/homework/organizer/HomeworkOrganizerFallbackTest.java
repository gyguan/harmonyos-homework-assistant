package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkOrganizerFallbackTest {

  @Test
  void organizerDefaultsModelDateToTodayWhenSourceHasNoDate() {
    var students = mock(StudentRepository.class);
    var assignments = mock(AssignmentService.class);
    var model = mock(HomeworkOrganizerModelClient.class);
    var service = new HomeworkOrganizerService(students, assignments, model);

    UUID family = UUID.randomUUID();
    StudentEntity student = new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    student.id = "student-1";
    student.familyId = family;
    when(students.findById("student-1")).thenReturn(Optional.of(student));
    when(model.available()).thenReturn(true);

    LocalDate tomorrow = LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(1);
    var candidate = new HomeworkOrganizerDtos.Candidate(
        "数学", "口算20题", "完成口算20题", "", tomorrow.toString(), 10,
        "数学：口算20题", 0.95, "", "", "", 0.0, "");
    when(model.organize(eq(student), eq("老师通知"), eq("数学：口算20题")))
        .thenReturn(Optional.of(List.of(candidate)));
    when(assignments.list(eq(family), eq("student-1"), isNull(), isNull(),
        anyLong(), anyLong(), anyString())).thenReturn(List.of());

    var result = service.organize(
        family, "student-1", new HomeworkOrganizerDtos.Request("数学：口算20题", "老师通知"));

    assertEquals(
        LocalDate.now(ZoneId.of("Asia/Shanghai")).toString(),
        result.assignments().getFirst().taskDate());
  }

  @Test
  void organizerKeepsRecognizedDateWhenSourceExplicitlySpecifiesTomorrow() {
    var students = mock(StudentRepository.class);
    var assignments = mock(AssignmentService.class);
    var model = mock(HomeworkOrganizerModelClient.class);
    var service = new HomeworkOrganizerService(students, assignments, model);

    UUID family = UUID.randomUUID();
    StudentEntity student = new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    student.id = "student-1";
    student.familyId = family;
    when(students.findById("student-1")).thenReturn(Optional.of(student));
    when(model.available()).thenReturn(true);

    LocalDate tomorrow = LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(1);
    var candidate = new HomeworkOrganizerDtos.Candidate(
        "数学", "口算20题", "完成口算20题", "", tomorrow.toString(), 10,
        "明天完成数学口算20题", 0.95, "", "", "", 0.0, "");
    when(model.organize(eq(student), eq("老师通知"), eq("明天完成数学口算20题")))
        .thenReturn(Optional.of(List.of(candidate)));

    var result = service.organize(
        family, "student-1",
        new HomeworkOrganizerDtos.Request("明天完成数学口算20题", "老师通知"));

    assertEquals(tomorrow.toString(), result.assignments().getFirst().taskDate());
  }

  @Test
  void numericQuestionRangeIsNotMistakenForTaskDate() {
    assertTrue(!HomeworkOrganizerService.hasExplicitTaskDate("数学完成第1-6题并订正"));
    assertTrue(HomeworkOrganizerService.hasExplicitTaskDate("数学作业明天完成第1-6题"));
    assertTrue(HomeworkOrganizerService.hasExplicitTaskDate("10月14日完成数学练习"));
  }

  @Test
  void marksLocalFallbackDuplicateSoParentUiCanIdentifyDegradedReview() {
    var students = mock(StudentRepository.class);
    var assignments = mock(AssignmentService.class);
    var model = mock(HomeworkOrganizerModelClient.class);
    var service = new HomeworkOrganizerService(students, assignments, model);

    UUID family = UUID.randomUUID();
    StudentEntity student = new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    student.id = "student-1";
    student.familyId = family;
    when(students.findById("student-1")).thenReturn(Optional.of(student));
    when(model.available()).thenReturn(true);

    var candidate = new HomeworkOrganizerDtos.Candidate(
        "数学", "口算20题", "完成口算20题", "", "今天", 10,
        "口算20题", 0.95, "", "", "", 0.0, "");
    when(model.organize(eq(student), eq("老师通知"), eq("数学：口算20题")))
        .thenReturn(Optional.of(List.of(candidate)));
    when(model.reviewDuplicates(anyList(), anyList(), anyString()))
        .thenReturn(Optional.empty());

    var existing = new AssignmentDtos.Response(
        "a-existing", "student-1", "SCHOOL", "MATH", "TEXT", "数学",
        "口算20题", "完成口算20题", "",
        LocalDate.now(ZoneId.of("Asia/Shanghai")).toString(),
        "NOT_STARTED", "老师通知", "口算20题", 10,
        0L, 0L, 0L, "", 1L);

    when(assignments.list(eq(family), eq("student-1"), isNull(), isNull(),
        anyLong(), anyLong(), contains("NOT_STARTED")))
        .thenReturn(List.of(existing));

    var result = service.organize(
        family, "student-1", new HomeworkOrganizerDtos.Request("数学：口算20题", "老师通知"));

    assertEquals("a-existing", result.assignments().getFirst().duplicateAssignmentId());
    assertTrue(result.assignments().getFirst().duplicateReason().startsWith("【本地兜底】"));
  }
}
