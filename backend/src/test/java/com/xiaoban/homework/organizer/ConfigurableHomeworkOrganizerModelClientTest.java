package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertFalse;
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
  void schemaKeepsAssignmentsRootAndBoundedExpectedMinutes() {
    String schema = ConfigurableHomeworkOrganizerModelClient.structuredSchema().toString();
    assertTrue(ConfigurableHomeworkOrganizerModelClient.structuredSchema().containsKey("properties"));
    assertTrue(schema.contains("assignments"));
    assertTrue(schema.contains("expectedMinutes"));
    assertTrue(schema.contains("minimum=5"));
    assertTrue(schema.contains("maximum=120"));
  }
}
