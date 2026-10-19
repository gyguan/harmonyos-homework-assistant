package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class HomeworkFeedbackAutoLearningServiceTest {
  private static HomeworkOrganizerFeedbackEntity feedback(UUID family, String student) {
    var f = new HomeworkOrganizerFeedbackEntity();
    f.id = UUID.randomUUID();
    f.familyId = family;
    f.studentId = student;
    f.batchId = "text-100";
    f.candidateId = "ai-text-100-1";
    f.teacherName = "学科归属:语文";
    f.subject = "语文";
    f.sourceExcerpt = "语文：朗读国13";
    f.originalTitle = "朗读国13";
    f.currentTitle = "朗读《国学》第13页";
    f.details = "国后面的数字表示国学课本对应页码";
    f.feedbackTypeCode = "SHORTHAND";
    return f;
  }
  private static HomeworkOrganizerAiSnapshotEntity original() {
    var s = new HomeworkOrganizerAiSnapshotEntity();
    s.candidateId = "ai-text-100-1";
    s.teacherName = "";
    s.subject = "语文";
    s.title = "朗读国13";
    s.sourceExcerpt = "语文：朗读国13";
    return s;
  }
  private static HomeworkFeedbackAutoLearningService service(
      UUID family, String student, HomeworkTeacherExperienceRepository experiences,
      HomeworkOrganizerAiSnapshotRepository snapshots) {
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, student, "text-100")).thenReturn(List.of(original()));
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, student))
        .thenReturn(List.of());
    when(experiences.findBySourceFeedbackId(any(UUID.class)))
        .thenReturn(Optional.empty());
    when(experiences.save(any(HomeworkTeacherExperienceEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    return new HomeworkFeedbackAutoLearningService(experiences, snapshots);
  }

  @Test void shorthandFeedbackIsImmediatelyAnActiveStudentScopedRule() {
    UUID family = UUID.randomUUID();
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var f = feedback(family, "child-1");
    var learning = service(family, "child-1", experiences, snapshots);
    assertEquals("APPLIED", learning.evaluate(f));
    var rule = ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(experiences).save(rule.capture());
    assertEquals("FEEDBACK_AUTO", rule.getValue().origin);
    assertEquals("child-1", rule.getValue().studentId);
    assertEquals(family, rule.getValue().familyId);
    assertTrue(rule.getValue().active);
    assertEquals("学科归属:语文", rule.getValue().teacherName);
    assertEquals("朗读国*", rule.getValue().cue);
    assertEquals(f.id, rule.getValue().sourceFeedbackId);
    assertTrue(rule.getValue().interpretation.contains("国后面的数字"));
  }

  @Test void ordinaryFeedbackCanAutoApplyButOnlyToTheExactOriginalCue() {
    UUID family = UUID.randomUUID();
    var exp = mock(HomeworkTeacherExperienceRepository.class);
    var snap = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var learning = service(family, "child-1", exp, snap);
    var f = feedback(family, "child-1");
    f.feedbackTypeCode = "WRONG_SPLIT";
    f.details = "这一行有两个不同动作，要拆为两个任务";
    assertEquals("APPLIED", learning.evaluate(f));
    var cap = ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(exp).save(cap.capture());
    assertEquals("语文：朗读国13", cap.getValue().cue);
    assertFalse(cap.getValue().cue.contains("*"));
    assertTrue(cap.getValue().interpretation.contains("两个任务"));
  }

  @Test void sourceNotInAuthoritativeSnapshotNeverBecomesRule() {
    UUID family = UUID.randomUUID();
    var exp = mock(HomeworkTeacherExperienceRepository.class);
    var snap = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var learning = service(family, "child-1", exp, snap);
    var f = feedback(family, "child-1");
    f.sourceExcerpt = "英语：听读U4"; // client-side substitution
    assertEquals("PENDING_EVIDENCE", learning.evaluate(f));
    verify(exp, never()).save(any());
  }

  @Test void noMeaningfulCorrectionDoesNotClaimApplied() {
    UUID family = UUID.randomUUID();
    var exp = mock(HomeworkTeacherExperienceRepository.class);
    var snap = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var learning = service(family, "child-1", exp, snap);
    var f = feedback(family, "child-1");
    f.feedbackTypeCode = "DUPLICATE";
    f.details = "";
    f.currentTitle = f.originalTitle;
    assertEquals("PENDING_EVIDENCE", learning.evaluate(f));
    verify(exp, never()).save(any());
  }

  @Test void conflictingActiveRuleNeverSilentlyOverwritten() {
    UUID family = UUID.randomUUID();
    var exp = mock(HomeworkTeacherExperienceRepository.class);
    var snap = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var learning = service(family, "child-1", exp, snap);
    var prior = new HomeworkTeacherExperienceEntity();
    prior.active = true;
    prior.teacherName = "学科归属:语文";
    prior.subject = "语文";
    prior.cue = "朗读国*";
    prior.interpretation = "不同版本的解释";
    when(exp.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child-1"))
        .thenReturn(List.of(prior));
    assertEquals("REVIEW_REQUIRED", learning.evaluate(feedback(family, "child-1")));
    verify(exp, never()).save(any());
  }

  @Test void retryDoesNotReenableDisabledRule() {
    UUID family = UUID.randomUUID();
    var exp = mock(HomeworkTeacherExperienceRepository.class);
    var snap = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var learning = service(family, "child-1", exp, snap);
    var f = feedback(family, "child-1");
    var prior = new HomeworkTeacherExperienceEntity();
    prior.active = false;
    when(exp.findBySourceFeedbackId(f.id)).thenReturn(Optional.of(prior));
    assertEquals("APPLIED", learning.evaluate(f));
    verify(exp, never()).save(any());
  }

  @Test void unrelatedBatchOrStudentCannotCrossReadEvidence() {
    UUID family = UUID.randomUUID();
    var exp = mock(HomeworkTeacherExperienceRepository.class);
    var snap = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var learning = service(family, "child-1", exp, snap);
    var f = feedback(family, "child-2");
    assertEquals("PENDING_EVIDENCE", learning.evaluate(f));
    verify(exp, never()).save(any());
  }
  @Test void nextTextPromptReusesAutoCorrectionOnlyForMatchingStudentAndSubject() {
    UUID family = UUID.randomUUID();
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var feedback = feedback(family, "child-1");
    var learning = service(family, "child-1", experiences, snapshots);
    assertEquals("APPLIED", learning.evaluate(feedback));
    var cap = ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(experiences).save(cap.capture());
    var rule = cap.getValue();
    var students = mock(com.xiaoban.homework.student.StudentRepository.class);
    var student = new com.xiaoban.homework.student.StudentEntity() {};
    student.id = "child-1";
    student.familyId = family;
    var other = new com.xiaoban.homework.student.StudentEntity() {};
    other.id = "child-2";
    other.familyId = family;
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child-1"))
        .thenReturn(List.of(rule));
    var loader = new HomeworkTeacherExperienceService(experiences, students);
    assertTrue(loader.context(student, "家长录入文字", "语文：朗读国14", false)
        .contains("国后面的数字表示"));
    assertEquals("", loader.context(student, "家长录入文字",
        "数学：口算国14", false));
    assertEquals("", loader.context(student, "家长录入文字",
        "王老师：语文朗读国14", false));
    assertEquals("", loader.context(other, "家长录入文字", "语文：朗读国14", false));
  }

  @Test void imageRuleOnlyOffersConditionalGuidanceForLongExactCue() {
    UUID family = UUID.randomUUID();
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var students = mock(com.xiaoban.homework.student.StudentRepository.class);
    var row = new HomeworkTeacherExperienceEntity();
    row.teacherName = "学科归属:语文";
    row.subject = "语文";
    row.cue = "语文：课外阅读30分钟，完成心情日记";
    row.interpretation = "课外阅读和心情日记是两个不同任务";
    row.origin = "FEEDBACK_AUTO";
    row.active = true;
    row.exampleSource = "语文：课外阅读30分钟，完成心情日记";
    row.exampleResult = "";
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child-1"))
        .thenReturn(List.of(row));
    var student = new com.xiaoban.homework.student.StudentEntity() {};
    student.id = "child-1";
    student.familyId = family;
    var loader = new HomeworkTeacherExperienceService(experiences, students);
    var hint = loader.context(student, "拍照上传", "", true);
    assertTrue(hint.contains("图片里必须识别出符合的老师和线索"), hint);
    assertTrue(hint.contains("课外阅读和心情日记"));
  }

  @Test void clientProvidedTeacherMustNotOverrideServerSnapshotAttribution() {
    UUID family = UUID.randomUUID();
    var exp = mock(HomeworkTeacherExperienceRepository.class);
    var snap = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var learning = service(family, "child-1", exp, snap);
    var f = feedback(family, "child-1");
    f.teacherName = "未经核实的李老师";
    assertEquals("APPLIED", learning.evaluate(f));
    var saved = ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(exp).save(saved.capture());
    assertEquals("学科归属:语文", saved.getValue().teacherName);
  }

  @Test void parentExplainedVeryShortSchoolAbbreviationIsStillLearnable() {
    UUID family = UUID.randomUUID();
    var exp = mock(HomeworkTeacherExperienceRepository.class);
    var snap = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var source = original();
    source.subject = "英语";
    source.title = "U4";
    source.sourceExcerpt = "U4";
    when(snap.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, "child-1", "text-100")).thenReturn(List.of(source));
    when(exp.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child-1"))
        .thenReturn(List.of());
    when(exp.findBySourceFeedbackId(any(UUID.class))).thenReturn(Optional.empty());
    var record = feedback(family, "child-1");
    record.teacherName = "";
    record.subject = "英语";
    record.sourceExcerpt = "U4";
    record.originalTitle = "U4";
    record.currentTitle = "听读课本第4单元课文";
    record.details = "U表示Unit单元，数字是课文单元号";
    assertEquals("APPLIED", new HomeworkFeedbackAutoLearningService(exp, snap).evaluate(record));
    var saved = ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(exp).save(saved.capture());
    assertEquals("U*", saved.getValue().cue);
    assertEquals("学科归属:英语", saved.getValue().teacherName);
  }

  @Test void confirmedShorthandIsAvailableToImageAiOnlyAsConditionalGuidance() {
    UUID family = UUID.randomUUID();
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var students = mock(com.xiaoban.homework.student.StudentRepository.class);
    var row = new HomeworkTeacherExperienceEntity();
    row.teacherName = "学科归属:英语";
    row.subject = "英语";
    row.cue = "听读U*";
    row.interpretation = "家长确认U后面数字是英语课文单元号";
    row.origin = "FEEDBACK_AUTO";
    row.exampleSource = "英语：听读U4";
    row.exampleResult = "";
    row.active = true;
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child-1"))
        .thenReturn(List.of(row));
    var student = new com.xiaoban.homework.student.StudentEntity() {};
    student.id = "child-1";
    student.familyId = family;
    var loader = new HomeworkTeacherExperienceService(experiences, students);
    String hint = loader.context(student, "拍照上传", "", true);
    assertTrue(hint.contains("听读U*"));
    assertTrue(hint.contains("图片里必须识别出符合的老师和线索"));
    assertEquals("", loader.context(student, "家长录入文字", "数学：口算20题", false));
  }

  @Test void mixedChineseEnglishAbbreviationGeneralizesButPageReferencesDoNot() {
    assertEquals("听读U*", HomeworkFeedbackAutoLearningService.autoCue(
        "SHORTHAND", "英语：听读U4"));
    assertEquals("第13页", HomeworkFeedbackAutoLearningService.autoCue(
        "SHORTHAND", "第13页"));
  }

  @Test void parentExplainedExcerptFourPlusTwoLearnsReusableMeaningWithoutChangingTitle() {
    UUID family = UUID.randomUUID();
    var experiences = mock(HomeworkTeacherExperienceRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var original = original();
    original.title = "完成摘抄（4+2）";
    original.subject = "语文";
    original.sourceExcerpt = "摘抄：（4+2）";
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, "child-1", "text-100")).thenReturn(List.of(original));
    when(experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child-1"))
        .thenReturn(List.of());
    when(experiences.findBySourceFeedbackId(any(UUID.class))).thenReturn(Optional.empty());

    var feedback = feedback(family, "child-1");
    feedback.feedbackTypeCode = "WRONG_CONTENT";
    feedback.sourceExcerpt = "摘抄：（4+2）";
    feedback.originalTitle = "完成摘抄（4+2）";
    feedback.currentTitle = "完成摘抄（4+2）"; // only the description is corrected
    feedback.details = "对于摘抄这类作业，里面的数字代表多少个好词好句，比如4+2标识4个好词，2个好句";
    assertEquals("APPLIED",
        new HomeworkFeedbackAutoLearningService(experiences, snapshots).evaluate(feedback));
    var saved = org.mockito.ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(experiences).save(saved.capture());
    assertEquals("摘抄", saved.getValue().cue);
    assertTrue(saved.getValue().interpretation.contains(
        HomeworkExcerptCountConvention.CONFIRMED_MEANING));
    assertTrue(saved.getValue().active);
  }


}
