package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkFeedbackSubmitAutoApplyTest {
  @Test void submitAppliesVerifiedCorrectionWithoutSecondManualPromoteCall() {
    UUID family = UUID.randomUUID();
    var studentId = "child-1";
    var students = mock(com.xiaoban.homework.student.StudentRepository.class);
    var student = new com.xiaoban.homework.student.StudentEntity() {};
    student.id = studentId;
    student.familyId = family;
    when(students.findById(studentId)).thenReturn(Optional.of(student));
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var type = new HomeworkFeedbackTypeEntity();
    type.code = "SHORTHAND";
    type.enabled = true;
    type.canBecomeExperience = true;
    when(types.findById("SHORTHAND")).thenReturn(Optional.of(type));
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    when(feedback.findByFamilyIdAndStudentIdAndClientRequestId(
        family, studentId, "request-1")).thenReturn(Optional.empty());
    when(feedback.save(any(HomeworkOrganizerFeedbackEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var original = new HomeworkOrganizerAiSnapshotEntity();
    original.candidateId = "ai-batch1-1";
    original.title = "朗读国13";
    original.subject = "语文";
    original.sourceExcerpt = "语文：朗读国13";
    original.teacherName = "";
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, studentId, "batch1")).thenReturn(List.of(original));
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    when(experiences.findBySourceFeedbackId(any(UUID.class))).thenReturn(Optional.empty());
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, studentId))
        .thenReturn(List.of());
    when(experiences.save(any(HomeworkTeacherExperienceEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    var learning = new HomeworkFeedbackAutoLearningService(experiences, snapshots);
    var service = new HomeworkOrganizerFeedbackService(
        students, types, feedback, experiences, snapshots, learning);

    var request = new HomeworkOrganizerFeedbackDtos.Create(
        "request-1", "ai-batch1-1", "batch1", "", "语文", "SHORTHAND",
        "家长录入文字", "语文：朗读国13", "朗读国13", "朗读《国学》第13页",
        "国后数字是国学课本的页码");
    var result = service.submit(family, studentId, request);
    assertEquals("APPLIED", result.processingStatus());
    verify(experiences, times(1)).save(any(HomeworkTeacherExperienceEntity.class));
    verify(feedback, times(2)).save(any(HomeworkOrganizerFeedbackEntity.class));
  }

  @Test void evidenceFreeFeedbackReturnsPendingWithoutPretendingToLearn() {
    UUID family = UUID.randomUUID();
    var students = mock(com.xiaoban.homework.student.StudentRepository.class);
    var student = new com.xiaoban.homework.student.StudentEntity() {};
    student.familyId = family;
    student.id = "child-1";
    when(students.findById("child-1")).thenReturn(Optional.of(student));
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var type = new HomeworkFeedbackTypeEntity();
    type.code = "OTHER";
    type.enabled = true;
    when(types.findById("OTHER")).thenReturn(Optional.of(type));
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    when(feedback.findByFamilyIdAndStudentIdAndClientRequestId(
        family, "child-1", "request-2")).thenReturn(Optional.empty());
    when(feedback.save(any(HomeworkOrganizerFeedbackEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var learning = new HomeworkFeedbackAutoLearningService(experiences, snapshots);
    var service = new HomeworkOrganizerFeedbackService(
        students, types, feedback, experiences, snapshots, learning);
    var request = new HomeworkOrganizerFeedbackDtos.Create(
        "request-2", "unknown", "", "", "语文", "OTHER",
        "家长录入文字", "语文：朗读国13", "朗读国13", "朗读国13", "需要纠正");
    var result = service.submit(family, "child-1", request);
    assertEquals("PENDING_EVIDENCE", result.processingStatus());
    verify(experiences, never()).save(any());
  }
}
