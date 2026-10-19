package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkFeedbackLearningTest {
  static class Student extends StudentEntity {
    Student() { super(); }
  }

  @Test
  void wildcardMatchesOnlyDigitsWithoutConfusingOtherPages() {
    assertTrue(HomeworkExperienceCueMatcher.matches("国*", "王老师：朗读国13"));
    assertTrue(HomeworkExperienceCueMatcher.matches("听读U*", "听读U4/绘本"));
    assertFalse(HomeworkExperienceCueMatcher.matches("国*", "王老师：朗读国学"));
    assertFalse(HomeworkExperienceCueMatcher.matches("国*", "英语：听读U4"));
    assertFalse(HomeworkExperienceCueMatcher.valid("*"));
    assertFalse(HomeworkExperienceCueMatcher.valid("**"));
    assertFalse(HomeworkExperienceCueMatcher.valid("国**"));
    assertTrue(HomeworkExperienceCueMatcher.matches("订小白", "请订小白"));
  }

  private static Student owned(UUID family, String studentId, StudentRepository students) {
    var student = new Student();
    student.familyId = family;
    student.id = studentId;
    when(students.findById(studentId)).thenReturn(Optional.of(student));
    return student;
  }

  private static HomeworkOrganizerFeedbackEntity feedback(UUID family, String studentId) {
    var record = new HomeworkOrganizerFeedbackEntity();
    record.id = UUID.randomUUID();
    record.familyId = family;
    record.studentId = studentId;
    record.teacherName = "王老师";
    record.subject = "语文";
    record.feedbackTypeCode = "SHORTHAND";
    record.sourceExcerpt = "王老师：朗读国13";
    record.originalTitle = "读国13";
    record.currentTitle = "朗读《国学》第13页";
    record.processingStatus = "NEW";
    return record;
  }

  private static HomeworkFeedbackTypeEntity type(boolean eligible) {
    var result = new HomeworkFeedbackTypeEntity();
    result.code = "SHORTHAND";
    result.enabled = true;
    result.canBecomeExperience = eligible;
    return result;
  }

  @Test
  void confirmedParentFeedbackPromotesToStudentTeacherRuleAndIsIdempotent() {
    UUID family = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    owned(family, "child1", students);
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var feedbacks = mock(HomeworkOrganizerFeedbackRepository.class);
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var record = feedback(family, "child1");
    when(feedbacks.findByIdAndFamilyIdAndStudentId(record.id, family, "child1"))
        .thenReturn(Optional.of(record));
    when(types.findById("SHORTHAND")).thenReturn(Optional.of(type(true)));
    when(experiences.save(any(HomeworkTeacherExperienceEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    when(feedbacks.save(any(HomeworkOrganizerFeedbackEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of());
    var service = new HomeworkOrganizerFeedbackService(students, types, feedbacks, experiences);
    var input = new HomeworkOrganizerFeedbackDtos.Promote(
        "国*", "国后面的数字代表《国学》课本对应页码，不要推测其它内容");
    var applied = service.promote(family, "child1", record.id, input);
    assertEquals("FEEDBACK_APPROVED", applied.origin());
    assertEquals(record.id, applied.sourceFeedbackId());
    var captured = org.mockito.ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(experiences).save(captured.capture());
    assertEquals("child1", captured.getValue().studentId);
    assertEquals(family, captured.getValue().familyId);
    assertEquals("王老师", captured.getValue().teacherName);
    assertEquals("国*", captured.getValue().cue);
    assertEquals("APPLIED", record.processingStatus);
    assertTrue(applied.active());
    var saved = new HomeworkTeacherExperienceEntity();
    saved.id = applied.id();
    saved.familyId = family;
    saved.studentId = "child1";
    saved.teacherName = "王老师";
    saved.subject = "语文";
    saved.cue = "国*";
    saved.interpretation = input.interpretation();
    saved.sourceFeedbackId = record.id;
    saved.origin = "FEEDBACK_APPROVED";
    saved.active = false;
    when(experiences.findBySourceFeedbackId(record.id)).thenReturn(Optional.of(saved));
    var again = service.promote(family, "child1", record.id, input);
    assertEquals(applied.id(), again.id());
    assertTrue(again.active());
    verify(experiences, times(2)).save(any(HomeworkTeacherExperienceEntity.class));
  }

  @Test
  void rejectsUnrelatedCueUnknownTeacherAndIneligibleCategory() {
    UUID family = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    owned(family, "child1", students);
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var feedbacks = mock(HomeworkOrganizerFeedbackRepository.class);
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var record = feedback(family, "child1");
    when(feedbacks.findByIdAndFamilyIdAndStudentId(record.id, family, "child1"))
        .thenReturn(Optional.of(record));
    when(types.findById("SHORTHAND")).thenReturn(Optional.of(type(true)));
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of());
    var service = new HomeworkOrganizerFeedbackService(students, types, feedbacks, experiences);
    var meaning = "国代表国学课本的页码，只按原文数字";
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.promote(family, "child1", record.id,
            new HomeworkOrganizerFeedbackDtos.Promote("听读U*", meaning)));
    record.teacherName = "";
    record.sourceLabel = "家长录入文字";
    record.sourceExcerpt = "语文：朗读国13";
    when(experiences.save(any(HomeworkTeacherExperienceEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    var subjectRule = service.promote(family, "child1", record.id,
        new HomeworkOrganizerFeedbackDtos.Promote("国*", meaning));
    assertEquals("学科归属:语文", subjectRule.teacherName());
    record.teacherName = "王老师";
    when(types.findById("SHORTHAND")).thenReturn(Optional.of(type(false)));
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.promote(family, "child1", record.id,
            new HomeworkOrganizerFeedbackDtos.Promote("国*", meaning)));
  }

  @Test
  void disabledRuleNeverReachesPromptAndCanBeRestored() {
    var students = mock(StudentRepository.class);
    var family = UUID.randomUUID();
    var student = owned(family, "child1", students);
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var record = new HomeworkTeacherExperienceEntity();
    record.id = UUID.randomUUID();
    record.familyId = family;
    record.studentId = "child1";
    record.teacherName = "王老师";
    record.subject = "语文";
    record.cue = "国*";
    record.interpretation = "国加数字为国学课本页码";
    record.exampleSource = "国13";
    record.exampleResult = "朗读国学第13页";
    record.active = true;
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(record));
    when(experiences.findByIdAndFamilyIdAndStudentId(record.id, family, "child1"))
        .thenReturn(Optional.of(record));
    when(experiences.save(any(HomeworkTeacherExperienceEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    var service = new HomeworkTeacherExperienceService(experiences, students);
    assertTrue(service.context(student, "王老师", "朗读国14", false).contains("国*"));
    service.setActive(family, "child1", record.id, false);
    assertEquals("", service.context(student, "王老师", "朗读国14", false));
    service.setActive(family, "child1", record.id, true);
    assertFalse(service.context(student, "李老师", "朗读国14", false).contains("国*"));
  }

  @Test
  void explicitlyBoundTeacherDoesNotReuseForwardedTeacherExperience() {
    var students = mock(StudentRepository.class);
    var family = UUID.randomUUID();
    var student = owned(family, "child1", students);
    var repository = mock(HomeworkTeacherExperienceRepository.class);
    var wang = new HomeworkTeacherExperienceEntity();
    wang.id = UUID.randomUUID();
    wang.familyId = family;
    wang.studentId = "child1";
    wang.teacherName = "王老师";
    wang.subject = "语文";
    wang.cue = "国*";
    wang.interpretation = "王老师的国学页码规则";
    wang.exampleSource = "";
    wang.exampleResult = "";
    wang.active = true;
    var li = new HomeworkTeacherExperienceEntity();
    li.id = UUID.randomUUID();
    li.familyId = family;
    li.studentId = "child1";
    li.teacherName = "李老师";
    li.subject = "语文";
    li.cue = "国*";
    li.interpretation = "李老师另一套不同教材规则";
    li.exampleSource = "";
    li.exampleResult = "";
    li.active = true;
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(wang, li));
    var service = new HomeworkTeacherExperienceService(repository, students);
    String result = service.context(student,
        "家长录入文字\\n[家长已确认老师：王老师]",
        "转发李老师消息：朗读国13", false);
    assertTrue(result.contains("王老师的国学页码规则"));
    assertFalse(result.contains("李老师另一套不同教材规则"));
  }

}
