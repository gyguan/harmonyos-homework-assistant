package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.xiaoban.homework.student.StudentEntity;
import org.junit.jupiter.api.Test;

class ConfigurableHomeworkOrganizerModelClientTest {
  static class TestStudent extends StudentEntity {
    TestStudent() { super(); }
  }

  @Test
  void promptKeepsOnlyNecessaryStudentContext() {
    TestStudent student = new TestStudent();
    student.name = "小宇";
    student.grade = "三年级";
    student.semester = "上学期";
    student.textbookSummary = "语文部编版 · 数学北师大版";

    String input = ConfigurableHomeworkOrganizerModelClient.buildInput(
        student, "家长录入文字", "语文背诵第12课");

    assertTrue(input.contains("三年级"));
    assertTrue(input.contains("语文部编版"));
    assertTrue(input.contains("语文背诵第12课"));
    assertFalse(input.contains("小宇"));
  }

  @Test
  void instructionsForbidInventingHomeworkDetailsAndRequestJsonOnly() {
    String instructions = ConfigurableHomeworkOrganizerModelClient.instructions();
    assertTrue(instructions.contains("不解答作业"));
    assertTrue(instructions.contains("不得编造"));
    assertTrue(instructions.contains("JSON"));
    assertTrue(instructions.contains("subject 字段必须严格填写语文、数学、英语、阅读、朗读、体育、实践、兴趣、其他之一"));
    assertTrue(instructions.contains("家长直接布置"));
  }

  @Test
  void instructionsRequestGradeAwareFocusedDurationEstimate() {
    String instructions = ConfigurableHomeworkOrganizerModelClient.instructions();
    assertTrue(instructions.contains("expectedMinutes"));
    assertTrue(instructions.contains("学生年级"));
    assertTrue(instructions.contains("5 到 120 分钟"));
    assertTrue(instructions.contains("不包含休息"));
  }

  @Test
  void normalizesSchoolAndExtracurricularSubjectLabels() {
    assertEquals("语文", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("语文作业"));
    assertEquals("数学", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("数学练习"));
    assertEquals("英语", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("英语听读"));
    assertEquals("数学", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("Math"));
    assertEquals("语文", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("Chinese Language Arts"));
    assertEquals("数学", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("Mathematics Homework"));
    assertEquals("英语", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("English Reading"));
    assertEquals("阅读", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("阅读任务"));
    assertEquals("朗读", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("朗诵练习"));
    assertEquals("体育", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("体育运动"));
    assertEquals("实践", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("劳动实践"));
    assertEquals("兴趣", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("兴趣拓展"));
    assertEquals("其他", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("其他"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("Science"));
  }

  @Test
  void conversionReportsRejectedAssignmentsInsteadOfSilentlyDroppingThem() {
    var result = ConfigurableHomeworkOrganizerModelClient.toCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(java.util.List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "科学", "观察植物", "观察并记录", "", "今天", 20, "观察植物", 0.9),
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文作业", "背诵第12课", "背诵课文", "", "明天", 15, "背诵第12课", 0.95))));

    assertEquals(2, result.sourceCount());
    assertEquals(1, result.candidates().size());
    assertEquals("语文", result.candidates().getFirst().subject());
    assertEquals(1, result.unsupportedSubjectCount());
    assertEquals(0, result.blankTitleCount());
    assertEquals(java.util.List.of("科学"), result.unsupportedSubjects());
  }

  @Test
  void schemaKeepsAssignmentsRootAndBoundedExpectedMinutes() {
    String schema = ConfigurableHomeworkOrganizerModelClient.structuredSchema().toString();
    assertTrue(ConfigurableHomeworkOrganizerModelClient.structuredSchema().containsKey("properties"));
    assertTrue(schema.contains("assignments"));
    assertTrue(schema.contains("expectedMinutes"));
    assertTrue(schema.contains("minimum=5"));
    assertTrue(schema.contains("maximum=120"));
  }
}
