package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class HomeworkOrganizerFeedbackServiceTest {
  static class TestStudent extends StudentEntity {
    TestStudent() { super(); }
  }

  private static HomeworkFeedbackTypeEntity option(String code, boolean requiresComment) {
    var entity = new HomeworkFeedbackTypeEntity();
    entity.code = code;
    entity.label = "数据库定义的反馈类型";
    entity.description = "非硬编码";
    entity.enabled = true;
    entity.requiresComment = requiresComment;
    entity.displayOrder = 10;
    return entity;
  }

  private static HomeworkOrganizerFeedbackDtos.Create request(String code, String details) {
    return new HomeworkOrganizerFeedbackDtos.Create(
        "request-1", "ai-import-1", "import-batch-1", "王老师", "语文", code,
        "老师通知", "朗读国13", "读国13", "朗读《国学》第13页", details);
  }

  private static HomeworkOrganizerFeedbackService service(UUID family, String studentId,
      StudentRepository students, HomeworkFeedbackTypeRepository types,
      HomeworkOrganizerFeedbackRepository feedback) {
    var student = new TestStudent();
    student.familyId = family;
    student.id = studentId;
    when(students.findById(studentId)).thenReturn(Optional.of(student));
    return new HomeworkOrganizerFeedbackService(students, types, feedback);
  }

  @Test
  void rendersTypeOptionsFromDatabaseRatherThanJavaEnumeration() {
    var students = mock(StudentRepository.class);
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    var family = UUID.randomUUID();
    when(types.findByEnabledTrueOrderByDisplayOrderAsc())
        .thenReturn(List.of(option("CUSTOM_FROM_DATABASE", true)));
    var handler = service(family, "student-a", students, types, feedback);
    var responses = handler.types(family, "student-a");
    assertEquals(1, responses.size());
    assertEquals("CUSTOM_FROM_DATABASE", responses.getFirst().code());
    assertTrue(responses.getFirst().requiresComment());
  }

  @Test
  void storesFeedbackAsEvidenceWithStudentAndTeacherBoundaries() {
    var students = mock(StudentRepository.class);
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    var family = UUID.randomUUID();
    when(types.findById("SHORTHAND")).thenReturn(Optional.of(option("SHORTHAND", true)));
    when(feedback.save(any(HomeworkOrganizerFeedbackEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    var handler = service(family, "student-a", students, types, feedback);
    handler.submit(family, "student-a", request("SHORTHAND", "国13 指国学第13页"));
    var captor = ArgumentCaptor.forClass(HomeworkOrganizerFeedbackEntity.class);
    verify(feedback).save(captor.capture());
    var result = captor.getValue();
    assertEquals(family, result.familyId);
    assertEquals("student-a", result.studentId);
    assertEquals("王老师", result.teacherName);
    assertEquals("NEW", result.processingStatus);
    assertEquals("国13 指国学第13页", result.details);
  }

  @Test
  void enforcesDatabaseDefinedCommentRequirementAndEnabledTypes() {
    var students = mock(StudentRepository.class);
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    var family = UUID.randomUUID();
    when(types.findById("SHORTHAND")).thenReturn(Optional.of(option("SHORTHAND", true)));
    var disabled = option("DISABLED", false);
    disabled.enabled = false;
    when(types.findById("DISABLED")).thenReturn(Optional.of(disabled));
    var handler = service(family, "student-a", students, types, feedback);
    assertThrows(ApiExceptions.BadRequest.class,
        () -> handler.submit(family, "student-a", request("SHORTHAND", "")));
    assertThrows(ApiExceptions.BadRequest.class,
        () -> handler.submit(family, "student-a", request("DISABLED", "原因")));
  }

  @Test
  void repeatedRequestReturnsExistingFeedbackWithoutSecondInsert() {
    var students = mock(StudentRepository.class);
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    var family = UUID.randomUUID();
    var record = new HomeworkOrganizerFeedbackEntity();
    record.id = UUID.randomUUID();
    record.candidateId = "ai-import-1";
    record.feedbackTypeCode = "SHORTHAND";
    record.processingStatus = "NEW";
    when(feedback.findByFamilyIdAndStudentIdAndClientRequestId(family, "student-a", "request-1"))
        .thenReturn(Optional.of(record));
    var handler = service(family, "student-a", students, types, feedback);
    assertEquals(record.id, handler.submit(family, "student-a", request("SHORTHAND", "重复")).id());
  }

  @Test
  void rejectsDifferentFamilyAccess() {
    var students = mock(StudentRepository.class);
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    var family = UUID.randomUUID();
    var handler = service(family, "student-a", students, types, feedback);
    assertThrows(ApiExceptions.NotFound.class,
        () -> handler.types(UUID.randomUUID(), "student-a"));
  }
}
