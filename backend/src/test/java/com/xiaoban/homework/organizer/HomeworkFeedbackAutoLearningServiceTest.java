package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class HomeworkFeedbackAutoLearningServiceTest {
  private record Setup(UUID family, HomeworkTeacherExperienceRepository experiences,
      HomeworkOrganizerAiSnapshotRepository snapshots,
      HomeworkFeedbackExperienceModel model, HomeworkFeedbackAutoLearningService service) {}

  private static HomeworkOrganizerFeedbackEntity report(UUID family, String student,
      String excerpt, String details) {
    var row = new HomeworkOrganizerFeedbackEntity();
    row.id = UUID.randomUUID();
    row.familyId = family;
    row.studentId = student;
    row.batchId = "batch-1";
    row.candidateId = "ai-batch-1";
    row.feedbackTypeCode = "WRONG_CONTENT";
    row.subject = "语文";
    row.sourceExcerpt = excerpt;
    row.originalTitle = "完成摘抄（4+2）";
    row.currentTitle = "完成摘抄（4+2）";
    row.details = details;
    return row;
  }

  private static Setup setup(String excerpt) {
    UUID family = UUID.randomUUID();
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var model = mock(HomeworkFeedbackExperienceModel.class);
    var original = new HomeworkOrganizerAiSnapshotEntity();
    original.studentId = "child-1";
    original.familyId = family;
    original.candidateId = "ai-batch-1";
    original.subject = "语文";
    original.teacherName = "";
    original.sourceExcerpt = excerpt;
    original.title = "完成摘抄（4+2）";
    original.instruction = "完成摘抄（4+2）";
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, "child-1", "batch-1")).thenReturn(List.of(original));
    when(experiences.findBySourceFeedbackId(any(UUID.class)))
        .thenReturn(Optional.empty());
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(
        family, "child-1")).thenReturn(List.of());
    when(experiences.save(any(HomeworkTeacherExperienceEntity.class)))
        .thenAnswer(inv -> inv.getArgument(0));
    when(model.available()).thenReturn(true);
    return new Setup(family, experiences, snapshots, model,
        new HomeworkFeedbackAutoLearningService(experiences, snapshots, model));
  }

  @Test void aiGeneralizesParentsExactFourPlusTwoExplanationWithNoJavaPatternRule() {
    String excerpt = "摘抄：（4+2）";
    Setup s = setup(excerpt);
    String note = "对于摘抄这类作业，里面的数字代表多少个好词好句，比如4+2标识4个好词，2个好句";
    var report = report(s.family(), "child-1", excerpt, note);
    when(s.model().extract(eq(report), any(HomeworkOrganizerAiSnapshotEntity.class)))
        .thenReturn(Optional.of(new HomeworkFeedbackExperienceModel.Experience(
            true, "摘抄", "当前语文摘抄类作业出现括号内 N+M 的要求时",
            "把 N 解为本次要摘抄的好词数量、M 解为好句数量；根据本次数字写出完整任务标题及要求，不照抄历史数量。",
            0.96)));
    assertEquals("APPLIED", s.service().evaluate(report));
    var saved = ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(s.experiences()).save(saved.capture());
    var rule = saved.getValue();
    assertEquals("FEEDBACK_AI", rule.origin);
    assertEquals("摘抄", rule.cue);
    assertEquals("学科归属:语文", rule.teacherName);
    assertEquals(report.id, rule.sourceFeedbackId);
    assertEquals(excerpt, rule.exampleSource);
    assertTrue(rule.interpretation.contains("N 解为"));
    assertTrue(rule.active);
  }

  @Test void noSnapshotMeansNoAiCallOrRule() {
    Setup s = setup("摘抄：（4+2）");
    var report = report(s.family(), "child-1", "篡改后的原文", "4+2是4个好词，2个好句");
    assertEquals("PENDING_EVIDENCE", s.service().evaluate(report));
    verify(s.model(), never()).extract(any(), any());
    verify(s.experiences(), never()).save(any());
  }

  @Test void unavailableAiIsTruthfullyReportedAsPending() {
    Setup s = setup("摘抄：（4+2）");
    when(s.model().available()).thenReturn(false);
    var report = report(s.family(), "child-1", "摘抄：（4+2）", "4+2是4个好词，2个好句");
    assertEquals("PENDING_AI", s.service().evaluate(report));
    verify(s.experiences(), never()).save(any());
  }

  @Test void modelMustExplicitlyApproveAndMeetConfidenceAndContentChecks() {
    Setup s = setup("语文：摘抄：（4+2）");
    var report = report(s.family(), "child-1", "语文：摘抄：（4+2）", "请按正确要求整理");
    when(s.model().extract(any(), any())).thenReturn(Optional.of(
        new HomeworkFeedbackExperienceModel.Experience(false, "", "", "", 0.95)));
    assertEquals("PENDING_EVIDENCE", s.service().evaluate(report));
    when(s.model().extract(any(), any())).thenReturn(Optional.of(
        new HomeworkFeedbackExperienceModel.Experience(true, "摘抄",
            "本次同类的摘抄作业中", "按本次家长确认的内容解释并展开任务标题", 0.3)));
    assertEquals("PENDING_EVIDENCE", s.service().evaluate(report));
    when(s.model().extract(any(), any())).thenReturn(Optional.of(
        new HomeworkFeedbackExperienceModel.Experience(true, "摘抄", "", "泛化规则", 0.98)));
    assertEquals("REVIEW_REQUIRED", s.service().evaluate(report));
    verify(s.experiences(), never()).save(any());
  }

  @Test void existingContradictoryRuleIsNotSilentlyOverwritten() {
    Setup s = setup("摘抄：（4+2）");
    var report = report(s.family(), "child-1", "摘抄：（4+2）", "4+2是4个好词，2个好句");
    when(s.model().extract(any(), any())).thenReturn(Optional.of(
        new HomeworkFeedbackExperienceModel.Experience(true, "摘抄",
            "本学生语文摘抄作业中有两数相加时",
            "第一数表示好词，第二数表示好句，按本次要求展开完整标题", 0.99)));
    var old = new HomeworkTeacherExperienceEntity();
    old.active = true;
    old.teacherName = "学科归属:语文";
    old.subject = "语文";
    old.cue = "摘抄";
    old.interpretation = "旧规则：不同数量对应不同任务要求";
    when(s.experiences().findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(
        s.family(), "child-1")).thenReturn(List.of(old));
    assertEquals("REVIEW_REQUIRED", s.service().evaluate(report));
    verify(s.experiences(), never()).save(any());
  }

  @Test void studentAndTeacherScopeComesOnlyFromOriginalServerSnapshot() {
    Setup s = setup("摘抄：（4+2）");
    var report = report(s.family(), "child-1", "摘抄：（4+2）",
        "4+2表示4个好词与2个好句");
    report.teacherName = "伪造的老师";
    when(s.model().extract(any(), any())).thenReturn(Optional.of(
        new HomeworkFeedbackExperienceModel.Experience(true, "摘抄",
            "语文中的摘抄类作业含两项数量时",
            "使用原文第一个数量描述好词，第二个数量描述好句", 0.98)));
    assertEquals("APPLIED", s.service().evaluate(report));
    var cap = ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(s.experiences()).save(cap.capture());
    assertEquals("学科归属:语文", cap.getValue().teacherName);
    assertEquals(s.family(), cap.getValue().familyId);
    assertEquals("child-1", cap.getValue().studentId);
  }
}
