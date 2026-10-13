package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.student.StudentEntity;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class ConfigurableHomeworkOrganizerModelClientTest {

  static class TestStudent extends StudentEntity {
    TestStudent() { super(); }
  }

  @Test
  void submitsSupplementaryTextAlongsideImageWithoutDuplicateMetadataPrompt() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    when(transport.completeWithImage(anyString(), anyString(), anyString(), anyString(), anyInt(),
        anyString(), anyMap())).thenReturn(java.util.Optional.of(
            "{\"recognizedText\":\"语文朗读\",\"assignments\":[]} "));
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), transport, JsonMapper.builder().build());

    client.organizeImage(
        new TestStudent(), "相册", "data:image/jpeg;base64,PRIVATE", " 数学口算20题 ");

    var instructions = org.mockito.ArgumentCaptor.forClass(String.class);
    var input = org.mockito.ArgumentCaptor.forClass(String.class);
    verify(transport).completeWithImage(
        anyString(), instructions.capture(), input.capture(),
        eq("data:image/jpeg;base64,PRIVATE"), eq(6000), anyString(), anyMap());

    assertTrue(input.getValue().contains("补充文字（可能为空）：\n数学口算20题"));
    assertFalse(instructions.getValue().contains("sameTaskGroup"));
    assertFalse(instructions.getValue().contains("duplicateAssignmentId"));
    assertFalse(instructions.getValue().contains("数学口算20题"));
    assertFalse(ConfigurableHomeworkOrganizerModelClient.imageInput(new TestStudent(), "相册", null)
        .endsWith("null"));
  }

  @Test
  void imageUpstreamStatusReachesServiceUnavailableResponse() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    when(transport.completeWithImage(anyString(), anyString(), anyString(), anyString(), anyInt(),
        anyString(), anyMap())).thenThrow(new com.xiaoban.homework.ai.ImageAiRequestException(
            406, com.xiaoban.homework.ai.ImageAiRequestException.Reason.REQUEST_REJECTED));
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), transport, JsonMapper.builder().build());

    var error = assertThrows(com.xiaoban.homework.common.ApiExceptions.ServiceUnavailable.class,
        () -> client.organizeImage(
            new TestStudent(), "相册", "data:image/jpeg;base64,PRIVATE", null));

    assertTrue(error.getMessage().contains("HTTP 406"));
    assertFalse(error.getMessage().contains("PRIVATE"));
  }

  @Test
  void imageResultKeepsMultipleSubjectsAndRejectsIncompleteOutput() {
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), null, JsonMapper.builder().build());
    String output = """
        {"recognizedText":"语文背诵；数学口算","assignments":[
          {"subject":"语文","title":"背诵","instruction":"背诵课文","textbookRef":"","taskDate":"今天",
           "expectedMinutes":10,"sourceExcerpt":"语文背诵","confidence":0.9},
          {"subject":"数学","title":"口算","instruction":"口算20题","textbookRef":"","taskDate":"今天",
           "expectedMinutes":15,"sourceExcerpt":"数学口算","confidence":0.8}
        ]}
        """;

    var result = client.parseImageOutput(output).orElseThrow();

    assertEquals(List.of("语文", "数学"),
        result.assignments().stream().map(HomeworkOrganizerDtos.Candidate::subject).toList());
    assertEquals("语文背诵；数学口算", result.recognizedText());
    assertTrue(client.parseImageOutput(output.replace("\"recognizedText\"", "\"unused\"")).isEmpty());
    assertTrue(client.parseImageOutput(output.replace("\"数学\"", "\"InvalidSubject\"")).isEmpty());
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
  void instructionsFocusOnOrganizationAndDoNotRequestDuplicateComparison() {
    String instructions = ConfigurableHomeworkOrganizerModelClient.instructions();

    assertTrue(instructions.contains("不解答作业"));
    assertTrue(instructions.contains("不得编造"));
    assertTrue(instructions.contains("expectedMinutes"));
    assertTrue(instructions.contains("5 到 120 分钟"));
    assertTrue(instructions.contains("JSON"));
    assertTrue(instructions.contains("重复表述直接合并"));
    assertFalse(instructions.contains("sameTaskGroup"));
    assertFalse(instructions.contains("已有任务"));
    assertFalse(instructions.contains("重复判定"));
  }

  @Test
  void normalizesSchoolAndExtracurricularSubjectLabels() {
    assertEquals("语文", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("语文作业"));
    assertEquals("数学", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("Math"));
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
  void conversionReportsRejectedAssignmentsAndClearsLegacyDuplicateFields() {
    var result = ConfigurableHomeworkOrganizerModelClient.toCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "科学", "观察植物", "观察并记录", "", "今天", 20, "观察植物", 0.9),
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文作业", "背诵第12课", "背诵课文", "", "明天", 15, "背诵第12课", 0.95))));

    assertEquals(2, result.sourceCount());
    assertEquals(1, result.candidates().size());
    assertEquals("语文", result.candidates().getFirst().subject());
    assertEquals("", result.candidates().getFirst().sameTaskGroup());
    assertEquals("", result.candidates().getFirst().duplicateAssignmentId());
    assertEquals(1, result.unsupportedSubjectCount());
  }

  @Test
  void schemaContainsOnlyOrganizationFields() {
    String schema = ConfigurableHomeworkOrganizerModelClient.structuredSchema().toString();

    assertTrue(schema.contains("assignments"));
    assertTrue(schema.contains("expectedMinutes"));
    assertTrue(schema.contains("minimum=5"));
    assertTrue(schema.contains("maximum=120"));
    assertFalse(schema.contains("sameTaskGroup"));
    assertFalse(schema.contains("duplicateAssignmentId"));
    assertFalse(schema.contains("duplicateConfidence"));
    assertFalse(schema.contains("duplicateReason"));
  }

  @Test
  void textOrganizerUsesSingleCompactRequest() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    when(transport.complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap()))
        .thenReturn(java.util.Optional.of("""
            {"assignments":[{"subject":"数学","title":"口算20题","instruction":"完成口算20题",
            "textbookRef":"","taskDate":"今天","expectedMinutes":10,"sourceExcerpt":"口算20题",
            "confidence":0.95}]}
            """));
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), transport, JsonMapper.builder().build());

    var result = client.organize(new TestStudent(), "老师通知", "数学：口算20题").orElseThrow();

    assertEquals(1, result.size());
    verify(transport).complete(
        anyString(), anyString(), anyString(), eq(1400), eq("homework_organization"), anyMap());
  }

  @Test
  void resolvesRelativeAndExplicitTaskDates() {
    ZoneId zone = ZoneId.of("Asia/Shanghai");
    LocalDate today = LocalDate.now(zone);
    LocalDate tomorrow = today.plusDays(1);

    assertEquals(today, ConfigurableHomeworkOrganizerModelClient.candidateTaskDate("今天"));
    assertEquals(tomorrow, ConfigurableHomeworkOrganizerModelClient.candidateTaskDate("明天"));
    assertEquals(tomorrow,
        ConfigurableHomeworkOrganizerModelClient.candidateTaskDate(tomorrow.toString()));
  }
}
