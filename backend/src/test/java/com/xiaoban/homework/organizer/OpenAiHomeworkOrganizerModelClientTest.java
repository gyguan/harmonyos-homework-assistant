package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.xiaoban.homework.student.StudentEntity;
import java.util.List;
import org.junit.jupiter.api.Test;

class OpenAiHomeworkOrganizerModelClientTest {
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

    String input = OpenAiHomeworkOrganizerModelClient.buildInput(student, "家长录入文字", "语文背诵第12课");

    assertTrue(input.contains("三年级"));
    assertTrue(input.contains("语文部编版"));
    assertTrue(input.contains("语文背诵第12课"));
    assertFalse(input.contains("小宇"));
  }

  @Test
  void instructionsForbidInventingHomeworkDetails() {
    String instructions = OpenAiHomeworkOrganizerModelClient.instructions();
    assertTrue(instructions.contains("不解答作业"));
    assertTrue(instructions.contains("不得编造"));
    assertTrue(instructions.contains("家长确认"));
  }

  @Test
  void extractsOutputTextFromResponsesPayload() {
    var response = new OpenAiHomeworkOrganizerModelClient.OpenAiResponse(List.of(
        new OpenAiHomeworkOrganizerModelClient.OpenAiOutput(List.of(
            new OpenAiHomeworkOrganizerModelClient.OpenAiContent("output_text", "{\"assignments\":[]}")))));
    assertTrue(OpenAiHomeworkOrganizerModelClient.extractText(response).isPresent());
  }
}
