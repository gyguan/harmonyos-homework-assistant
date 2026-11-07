package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkFeedbackSubmitAutoApplyTest {
  @Test void parentOnlyDescribesErrorAndModelGeneratesExperienceInSameSubmission() {
    UUID family = UUID.randomUUID();
    String studentId = "child-1";
    var students = mock(com.xiaoban.homework.student.StudentRepository.class);
    var student = new com.xiaoban.homework.student.StudentEntity() {};
    student.id = studentId;
    student.familyId = family;
    when(students.findById(studentId)).thenReturn(Optional.of(student));
    var types = mock(HomeworkFeedbackTypeRepository.class);
    var type = new HomeworkFeedbackTypeEntity();
    type.code = "WRONG_CONTENT";
    type.enabled = true;
    when(types.findById(type.code)).thenReturn(Optional.of(type));
    var feedback = mock(HomeworkOrganizerFeedbackRepository.class);
    when(feedback.findByFamilyIdAndStudentIdAndClientRequestId(
        family, studentId, "request-1")).thenReturn(Optional.empty());
    when(feedback.save(any(HomeworkOrganizerFeedbackEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var original = new HomeworkOrganizerAiSnapshotEntity();
    original.candidateId = "ai-batch1-1";
    original.title = "完成摘抄（4+2）";
    original.subject = "语文";
    original.sourceExcerpt = "摘抄：（4+2）";
    original.teacherName = "";
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, studentId, "batch1")).thenReturn(List.of(original));
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    when(experiences.findBySourceFeedbackId(any(UUID.class))).thenReturn(Optional.empty());
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, studentId))
        .thenReturn(List.of());
    var model = mock(HomeworkFeedbackExperienceModel.class);
    when(model.available()).thenReturn(true);
    when(model.extract(any(), any())).thenReturn(Optional.of(
        new HomeworkFeedbackExperienceModel.Experience(true, "摘抄",
            "语文摘抄作业中有两个数量并列时",
            "将本次前一个数字理解为好词数量，后一个数字理解为好句数量，完整写入标题",
            0.96)));
    when(experiences.save(any(HomeworkTeacherExperienceEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));
    var learning = new HomeworkFeedbackAutoLearningService(experiences, snapshots, model);
    var service = new HomeworkOrganizerFeedbackService(
        students, types, feedback, experiences, snapshots, learning);
    String details = "对于摘抄这类作业，里面的数字代表多少个好词好句，比如4+2标识4个好词，2个好句";
    var request = new HomeworkOrganizerFeedbackDtos.Create(
        "request-1", "ai-batch1-1", "batch1", "", "语文", "WRONG_CONTENT",
        "家长录入文字", "摘抄：（4+2）", "完成摘抄（4+2）", "完成摘抄（4+2）", details);
    var receipt = service.submit(family, studentId, request);
    assertEquals("APPLIED", receipt.processingStatus());
    verify(experiences, times(1)).save(any(HomeworkTeacherExperienceEntity.class));
    verify(feedback, times(2)).save(any(HomeworkOrganizerFeedbackEntity.class));
    verify(model).extract(any(), any());
  }

  @Test void missingEvidenceKeepsReportAndDoesNotCallModel() {
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
        .thenAnswer(inv -> inv.getArgument(0));
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var model = mock(HomeworkFeedbackExperienceModel.class);
    var learning = new HomeworkFeedbackAutoLearningService(experiences, snapshots, model);
    var service = new HomeworkOrganizerFeedbackService(
        students, types, feedback, experiences, snapshots, learning);
    var request = new HomeworkOrganizerFeedbackDtos.Create(
        "request-2", "unknown", "", "", "语文", "OTHER",
        "家长录入文字", "语文：朗读国13", "朗读国13", "朗读国13", "需要纠正");
    var receipt = service.submit(family, "child-1", request);
    assertEquals("PENDING_EVIDENCE", receipt.processingStatus());
    verify(model, never()).extract(any(), any());
    verify(experiences, never()).save(any());
  }
}
