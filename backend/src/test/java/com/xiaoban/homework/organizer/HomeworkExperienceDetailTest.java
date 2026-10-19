package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkExperienceDetailTest {
  private static StudentEntity owner(UUID family, String id) {
    var student = new StudentEntity() {};
    student.id = id;
    student.familyId = family;
    return student;
  }

  @Test
  void fullDetailsIncludesOriginalParentExplanationAndBeforeAfterValues() {
    UUID family = UUID.randomUUID();
    UUID experienceId = UUID.randomUUID();
    UUID feedbackId = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    when(students.findById("child-1"))
        .thenReturn(Optional.of(owner(family, "child-1")));
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var row = new HomeworkTeacherExperienceEntity();
    row.id = experienceId;
    row.familyId = family;
    row.studentId = "child-1";
    row.teacherName = "学科归属:语文";
    row.subject = "语文";
    row.cue = "国*";
    row.interpretation = "家长确认该缩写代表国学课本的对应页码";
    row.exampleSource = "语文：朗读国13";
    row.exampleResult = "朗读《国学》第13页";
    row.origin = "FEEDBACK_AUTO";
    row.active = true;
    row.sourceFeedbackId = feedbackId;
    row.updatedAt = Instant.parse("2026-10-19T02:00:00Z");
    when(experiences.findByIdAndFamilyIdAndStudentId(experienceId, family, "child-1"))
        .thenReturn(Optional.of(row));

    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    var evidence = new HomeworkOrganizerFeedbackEntity();
    evidence.id = feedbackId;
    evidence.familyId = family;
    evidence.studentId = "child-1";
    evidence.feedbackTypeCode = "SHORTHAND";
    evidence.details = "老师的国13表示国学课本第13页，不是第13题";
    evidence.originalTitle = "朗读第13题";
    evidence.currentTitle = "朗读《国学》第13页";
    evidence.sourceLabel = "家长导入文字";
    evidence.sourceExcerpt = "语文：朗读国13";
    evidence.processingStatus = "APPLIED";
    evidence.createdAt = Instant.parse("2026-10-19T01:00:00Z");
    when(feedback.findByIdAndFamilyIdAndStudentId(feedbackId, family, "child-1"))
        .thenReturn(Optional.of(evidence));

    var service = new HomeworkTeacherExperienceService(experiences, students, feedback);
    var result = service.detail(family, "child-1", experienceId);
    assertEquals("FEEDBACK_AUTO", result.experience().origin());
    assertEquals("语文：朗读国13", result.experience().exampleSource());
    assertEquals("朗读《国学》第13页", result.experience().exampleResult());
    assertEquals("老师的国13表示国学课本第13页，不是第13题", result.feedback().details());
    assertEquals("SHORTHAND", result.feedback().typeCode());
    verify(feedback).findByIdAndFamilyIdAndStudentId(feedbackId, family, "child-1");
  }

  @Test
  void anExperienceCannotBeReadAcrossFamiliesOrStudents() {
    var family = UUID.randomUUID();
    var otherFamily = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    when(students.findById("child-1")).thenReturn(Optional.of(owner(family, "child-1")));
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    var service = new HomeworkTeacherExperienceService(experiences, students, feedback);
    assertThrows(ApiExceptions.NotFound.class,
        () -> service.detail(otherFamily, "child-1", UUID.randomUUID()));
    var id = UUID.randomUUID();
    assertThrows(ApiExceptions.NotFound.class,
        () -> service.detail(family, "child-1", id));
    verify(experiences).findByIdAndFamilyIdAndStudentId(id, family, "child-1");
    verifyNoInteractions(feedback);
  }

  @Test
  void oldManualExperienceWithoutFeedbackStillShowsItsFullRule() {
    var family = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    when(students.findById("child-1")).thenReturn(Optional.of(owner(family, "child-1")));
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    var id = UUID.randomUUID();
    var rule = new HomeworkTeacherExperienceEntity();
    rule.id = id;
    rule.sourceFeedbackId = null;
    rule.interpretation = "旧版手工记录，已包含完整的原文和解释";
    rule.exampleSource = "老师原文";
    rule.exampleResult = "家长确认结果";
    when(experiences.findByIdAndFamilyIdAndStudentId(id, family, "child-1"))
        .thenReturn(Optional.of(rule));
    var result = new HomeworkTeacherExperienceService(experiences, students, feedback)
        .detail(family, "child-1", id);
    assertNull(result.feedback());
    assertEquals("老师原文", result.experience().exampleSource());
    verifyNoInteractions(feedback);
  }
}
