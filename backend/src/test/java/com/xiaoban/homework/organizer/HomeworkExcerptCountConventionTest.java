package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkExcerptCountConventionTest {
  private static HomeworkTeacherExperienceEntity saved(String cue, String example,
      String meaning, String student, UUID family) {
    var rule = new HomeworkTeacherExperienceEntity();
    rule.id = UUID.randomUUID();
    rule.familyId = family;
    rule.studentId = student;
    rule.teacherName = "学科归属:语文";
    rule.subject = "语文";
    rule.cue = cue;
    rule.exampleSource = example;
    rule.interpretation = meaning;
    rule.origin = "FEEDBACK_AUTO";
    rule.active = true;
    rule.exampleResult = "";
    return rule;
  }

  private static HomeworkOrganizerDtos.Candidate candidate(String subject,
      String title, String instruction, String excerpt) {
    return new HomeworkOrganizerDtos.Candidate(
        subject, title, instruction, "待家长确认", "2026-10-19", 20,
        excerpt, 0.92, "", "", "", 0.0, "");
  }

  private static StudentEntity student(String id, UUID family) {
    var row = new StudentEntity() {};
    row.id = id;
    row.familyId = family;
    return row;
  }

  @Test void confirmsExistingUserFeedbackWithoutResubmittingAndGeneralizesFutureNumbers() {
    String source = "摘抄：（4+2）";
    String feedback = "家长在这份原文上反馈「WRONG_CONTENT」。家长指出："
        + "对于摘抄这类作业，里面的数字代表多少个好词好句，比如4+2标识4个好词，2个好句。"
        + "仅当原文证据支持时参考，不照搬本例的页码、日期、题号。";
    var oldRule = saved(source, source, feedback, "child1", UUID.randomUUID());
    assertTrue(HomeworkExcerptCountConvention.isConfirmed(oldRule));
    assertEquals("摘抄", HomeworkExcerptCountConvention.learnedCue(
        source, "对于摘抄这类作业，比如4+2表示4个好词，2个好句"));
    assertEquals("摘抄4个好词、2个好句",
        HomeworkExcerptCountConvention.extract(source).title());
    assertEquals("摘抄5个好词、1个好句",
        HomeworkExcerptCountConvention.extract("摘抄 (5＋1)").title());
    assertNull(HomeworkExcerptCountConvention.extract("口算：（4+2）"));
  }

  @Test void stillRequiresExplicitMappingAndNeverAssumesGlobalMeaning() {
    assertFalse(HomeworkExcerptCountConvention.confirmedMeaning(
        "摘抄：（4+2）", "请完成4+2摘抄，数字暂不明确"));
    assertFalse(HomeworkExcerptCountConvention.confirmedMeaning(
        "摘抄：（4+2）", "4个好句，2个好词"));
    assertFalse(HomeworkExcerptCountConvention.confirmedMeaning(
        "摘抄：（4+2）", "2个好词，4个好句"));
    assertEquals("", HomeworkExcerptCountConvention.learnedCue(
        "摘抄：（4+2）", "4个好句，2个好词"));
  }

  @Test void scopedPostprocessingRewritesVagueAiOutputButKeepsOriginalEvidence() {
    UUID family = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    var repo = mock(HomeworkTeacherExperienceRepository.class);
    var row = saved("摘抄：（4+2）", "摘抄：（4+2）",
        "家长指出：4+2标识4个好词，2个好句", "child1", family);
    when(repo.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(row));
    var service = new HomeworkTeacherExperienceService(repo, students);
    StudentEntity student = student("child1", family);
    String nextSource = "今天的作业：摘抄：（3+2）";
    var input = candidate("语文", "完成摘抄（3+2）",
        "请完成摘抄（3+2），拍照提交", "摘抄：（3+2）");
    assertTrue(service.context(student, "家长录入文字", nextSource, false)
        .contains("前一数是好词数量"));
    var output = service.applyConfirmedExcerptCounts(
        student, "家长录入文字", nextSource, List.of(input));
    assertEquals("完成摘抄3个好词、2个好句", output.getFirst().title());
    assertTrue(output.getFirst().instruction().contains("3个好词、2个好句"));
    assertTrue(output.getFirst().instruction().contains("拍照提交"));
    assertEquals("摘抄：（3+2）", output.getFirst().sourceExcerpt());
    assertEquals(20, output.getFirst().expectedMinutes());
  }

  @Test void disabledExperienceOtherStudentSubjectAndOtherTeacherNeverApply() {
    UUID family = UUID.randomUUID();
    var repo = mock(HomeworkTeacherExperienceRepository.class);
    var students = mock(StudentRepository.class);
    var row = saved("摘抄：（4+2）", "摘抄：（4+2）",
        "4个好词，2个好句", "child1", family);
    when(repo.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(row));
    var service = new HomeworkTeacherExperienceService(repo, students);
    var input = candidate("语文", "完成摘抄（5+1）", "完成摘抄", "摘抄：（5+1）");
    assertEquals("完成摘抄（5+1）",
        service.applyConfirmedExcerptCounts(
            student("child2", family), "", "摘抄：（5+1）", List.of(input)).getFirst().title());
    assertEquals("完成摘抄（5+1）",
        service.applyConfirmedExcerptCounts(
            student("child1", family), "王老师：通知", "摘抄：（5+1）", List.of(input)).getFirst().title());
    assertEquals("完成摘抄（5+1）",
        service.applyConfirmedExcerptCounts(
            student("child1", family), "", "摘抄：（9+1）", List.of(input)).getFirst().title());
    var otherSubject = candidate("数学", "完成摘抄（5+1）", "完成摘抄", "摘抄：（5+1）");
    assertEquals("完成摘抄（5+1）",
        service.applyConfirmedExcerptCounts(
            student("child1", family), "", "摘抄：（5+1）", List.of(otherSubject)).getFirst().title());
    row.active = false;
    assertEquals("完成摘抄（5+1）",
        service.applyConfirmedExcerptCounts(
            student("child1", family), "", "摘抄：（5+1）", List.of(input)).getFirst().title());
  }

  @Test void imageRecognizedTextAlsoUsesConfirmedRule() {
    UUID family = UUID.randomUUID();
    var repo = mock(HomeworkTeacherExperienceRepository.class);
    var students = mock(StudentRepository.class);
    var row = saved("摘抄", "摘抄：（4+2）",
        HomeworkExcerptCountConvention.CONFIRMED_MEANING, "child1", family);
    when(repo.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(row));
    var service = new HomeworkTeacherExperienceService(repo, students);
    assertTrue(service.context(student("child1", family), "拍照上传", "", true)
        .contains("前一数是好词数量"));
    var output = service.applyConfirmedExcerptCounts(
        student("child1", family), "拍照上传", "摘抄：（5+2）",
        List.of(candidate("语文", "完成摘抄（5+2）",
            "摘抄：（5+2）", "摘抄：（5+2）")));
    assertEquals("完成摘抄5个好词、2个好句", output.getFirst().title());
  }
}
