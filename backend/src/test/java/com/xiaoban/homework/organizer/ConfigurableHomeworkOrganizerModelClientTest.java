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
            "{\"assignments\":[{\"subject\":\"数学\",\"title\":\"口算20题\",\"instruction\":\"完成口算20题\",\"textbookRef\":\"\",\"taskDate\":\"今天\",\"expectedMinutes\":10,\"sourceExcerpt\":\"数学口算20题\",\"confidence\":0.9}]}"));
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), transport, JsonMapper.builder().build());

    client.organizeImage(
        new TestStudent(), "相册", "data:image/jpeg;base64,PRIVATE", " 数学口算20题 ");

    var instructions = org.mockito.ArgumentCaptor.forClass(String.class);
    var input = org.mockito.ArgumentCaptor.forClass(String.class);
    verify(transport).completeWithImage(
        anyString(), instructions.capture(), input.capture(),
        eq("data:image/jpeg;base64,PRIVATE"), eq(3000), anyString(), anyMap());

    assertTrue(input.getValue().contains("补充文字（可能为空）：\n数学口算20题"));
    assertFalse(instructions.getValue().contains("sameTaskGroup"));
    assertFalse(instructions.getValue().contains("duplicateAssignmentId"));
    assertFalse(instructions.getValue().contains("数学口算20题"));
    assertTrue(instructions.getValue().contains("不要额外") ||
        ConfigurableHomeworkOrganizerModelClient.imageInput(new TestStudent(), "相册", null).contains("不要额外转写整张图片"));
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
        {"assignments":[
          {"subject":"语文","title":"背诵","instruction":"背诵课文","textbookRef":"","taskDate":"今天",
           "expectedMinutes":10,"sourceExcerpt":"语文背诵","confidence":0.9},
          {"subject":"数学","title":"口算","instruction":"口算20题","textbookRef":"","taskDate":"今天",
           "expectedMinutes":15,"sourceExcerpt":"数学口算","confidence":0.8}
        ]}
        """;

    var result = client.parseImageOutput(output).orElseThrow();

    assertEquals(List.of("语文", "数学"),
        result.assignments().stream().map(HomeworkOrganizerDtos.Candidate::subject).toList());
    assertEquals("语文背诵\n数学口算", result.recognizedText());
    assertTrue(client.parseImageOutput("{\"assignments\":[]}").isEmpty());
    assertTrue(client.parseImageOutput(output.replace("\"数学\"", "\"InvalidSubject\"")).isEmpty());
  }

  @Test
  void imageOutputIsAcceptedWhenGlmDropsTheAssignmentsWrapper() {
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), null, JsonMapper.builder().build());
    // 2026-10-13 线上 503 的原始输出形态：不发 response_format 时 glm-4.6v-flashx 直接以数组为根，
    // 且不带 textbookRef，外层还包了代码围栏。解析必须容忍，否则整条截图识别链路挂掉。
    String arrayRoot = """
        ```json
        [
          {"subject": "语文", "taskDate": "2026-10-13", "sourceExcerpt": "1.语文：抄写第12课生字表两遍",
           "confidence": 1, "title": "语文作业：抄写生字表", "instruction": "抄写两遍", "expectedMinutes": 15},
          {"subject": "数学", "taskDate": "2026-10-13", "sourceExcerpt": "2.数学：练习册 P34-P35",
           "confidence": 1, "title": "数学作业：练习册", "instruction": "完成 P34-P35", "expectedMinutes": 18}
        ]
        ```
        """;

    var result = client.parseImageOutput(arrayRoot).orElseThrow();

    assertEquals(List.of("语文", "数学"),
        result.assignments().stream().map(HomeworkOrganizerDtos.Candidate::subject).toList());
    assertEquals("AI_IMAGE", result.mode());
    // textbookRef 缺失时按约定回退到"待家长确认"
    assertTrue(result.assignments().stream()
        .allMatch(item -> "待家长确认".equals(item.textbookRef())));
  }

  @Test
  void imageOutputToleratesPreambleAndTrailingChatter() {
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), null, JsonMapper.builder().build());

    var result = client.parseImageOutput("好的，我识别到如下作业：\n"
        + "[{\"subject\":\"英语\",\"title\":\"跟读\",\"instruction\":\"跟读三遍\",\"taskDate\":\"2026-10-13\","
        + "\"expectedMinutes\":10,\"sourceExcerpt\":\"英语跟读\",\"confidence\":0.9}]\n"
        + "如需调整请告诉我。").orElseThrow();

    assertEquals(1, result.assignments().size());
    assertEquals("英语", result.assignments().get(0).subject());
  }

  @Test
  void imageAvailabilityFollowsTheConfiguredModelCapabilityNotJustTheApiKey() {
    var properties = new AiProviderProperties();
    properties.setBaseUrl("https://open.bigmodel.cn/api/paas/v4");
    properties.setApiKey("test-key");
    properties.setOrganizerModel("glm-4-flash");
    var transport = new com.xiaoban.homework.ai.OpenAiCompatibleTransport(properties,
        new com.xiaoban.homework.ai.AiProviderCapabilityResolver(properties),
        JsonMapper.builder().build());
    var client = new ConfigurableHomeworkOrganizerModelClient(properties, transport,
        JsonMapper.builder().build());

    // 线上真实故障：把图片流程指向纯文本模型时，接口调用前就必须判定为不可用。
    assertTrue(client.available());
    assertFalse(client.imageAvailable());

    properties.setImageOrganizerModel("glm-4.6v-flashx");
    assertTrue(client.imageAvailable());
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
  void instructionsDemandContentRichTitles() {
    // 家长反馈：标题只写「语文作业」「完成练习」，孩子看标题不知道要做什么。
    // 提示词必须把「动作 + 具体内容 + 要求」写进 title，并给出正例与禁止项。
    String instructions = ConfigurableHomeworkOrganizerModelClient.instructions();

    assertTrue(instructions.contains("title 是孩子看到作业的第一句话"));
    assertTrue(instructions.contains("动作 + 具体内容 + 要求"));
    assertTrue(instructions.contains("篇名、单元、页码、题号"));
    assertTrue(instructions.contains("禁止只写"));
    assertTrue(instructions.contains("60 个汉字"));
  }

  @Test
  void splitsMergedNumberedItemsIntoOneTaskEach() {
    // 线上真实黑板图：语文格子里写了「1、复习P28-38 周一练习」「2、预习8、10课 订正小白张」，
    // glm-4.6v-flashx 把它们并成一条，第 2 点只剩在 instruction 里，家长直接漏做。
    var result = ConfigurableHomeworkOrganizerModelClient.toCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", "复习P28-38 周一练习",
                "1、复习P28-38，周一练习 2、预习8、10课，订正小白张", "部编版", "2026-10-16",
                15, "1、复习P28-38. 周一练习 2、预习8、10课 订小白张", 0.9))));

    assertEquals(2, result.candidates().size());
    assertEquals("复习P28-38，周一练习", result.candidates().get(0).title());
    assertEquals("预习8、10课，订正小白张", result.candidates().get(1).title());
    assertEquals("语文", result.candidates().get(1).subject());
    assertEquals(15, result.candidates().get(1).expectedMinutes());
  }

  @Test
  void splitsCircledNumberedItems() {
    var result = ConfigurableHomeworkOrganizerModelClient.toCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", "抄写和背诵", "①抄写第12课生字表两遍 ②背诵《古诗二首》并默写", "部编版",
                "2026-10-16", 20, "①抄写 …②背诵 …", 0.9))));

    assertEquals(2, result.candidates().size());
    assertEquals("抄写第12课生字表两遍", result.candidates().get(0).title());
    assertEquals("背诵《古诗二首》并默写", result.candidates().get(1).title());
  }

  @Test
  void keepsSingleTaskWhenDigitsAreNotAnOrdinalList() {
    // 「第1、2课」「P32-34」都不是序号，不能被拆成多条
    var result = ConfigurableHomeworkOrganizerModelClient.toCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", "预习第1、2课", "预习课本第1、2课，读熟P32-34", "部编版", "2026-10-16",
                20, "预习第1、2课", 0.9))));

    assertEquals(1, result.candidates().size());
    assertEquals("预习第1、2课", result.candidates().getFirst().title());
  }

  @Test
  void conversionClampsOverlongTitleToDatabaseLimit() {
    // assignment.title 是 varchar(300)，超长会直接报库错误；写长标题的提示词更容易撞上。
    String tooLong = "背诵".repeat(400);
    var result = ConfigurableHomeworkOrganizerModelClient.toCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", tooLong, "背诵课文", "部编版", "2026-10-17", 20, "背诵", 0.9))));

    assertEquals(1, result.candidates().size());
    assertEquals(300, result.candidates().getFirst().title().length());
  }

  @Test
  void textOrganizerKeepsEveryAssignmentWhenModelOmitsFields() {
    // 2026-10-14 线上回归：AI_STRUCTURED_OUTPUT=false 时不发 response_format，
    // glm-4-flash 只输出 subject/title/instruction/taskDate/expectedMinutes/sourceExcerpt，
    // 经常省略 confidence 与 textbookRef。Spring Boot 4 用 Jackson 3，
    // 其 FAIL_ON_NULL_FOR_PRIMITIVES 默认为 true，会因 confidence 缺失直接抛
    // MismatchedInputException，导致 /homework/organize 返回 503，
    // App 静默退回本地解析后"一段话只整理出一个任务"。
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    when(transport.complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap()))
        .thenReturn(java.util.Optional.of("""
            {"assignments":[
              {"subject":"语文","taskDate":"2026-10-14","expectedMinutes":30,
               "sourceExcerpt":"语文抄写第12课生字表两遍","title":"语文作业","instruction":"抄写生字表两遍"},
              {"subject":"数学","taskDate":"2026-10-14",
               "sourceExcerpt":"数学练习册P34-P35","title":"数学作业","instruction":"完成P34-P35"},
              {"subject":"英语","taskDate":"2026-10-14","expectedMinutes":15,
               "sourceExcerpt":"英语跟读Unit 3","title":"英语作业","instruction":"跟读三遍",
               "textbookRef":"沪教版","confidence":0.9}
            ]}
            """));
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), transport, JsonMapper.builder().build());

    var result = client.organize(new TestStudent(), "家长录入文字", "语文数学英语三段作业").orElseThrow();

    assertEquals(3, result.size());
    assertEquals(List.of("语文", "数学", "英语"),
        result.stream().map(HomeworkOrganizerDtos.Candidate::subject).toList());
    assertEquals(List.of(30, 20, 15),
        result.stream().map(HomeworkOrganizerDtos.Candidate::expectedMinutes).toList());
    assertEquals(0.8, result.get(1).confidence(), 0.0001);
  }

  @Test
  void conversionFallsBackWhenPrimitiveFieldsAreAbsentOrNull() {
    var result = ConfigurableHomeworkOrganizerModelClient.toCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", "背诵第12课", "背诵课文", null, "2026-10-14", null, null, null))));

    assertEquals(1, result.candidates().size());
    assertEquals(20, result.candidates().getFirst().expectedMinutes());
    assertEquals(0.8, result.candidates().getFirst().confidence(), 0.0001);
    assertEquals("待家长确认", result.candidates().getFirst().textbookRef());
    assertEquals(1, result.missingFieldCount());
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
    assertFalse(ConfigurableHomeworkOrganizerModelClient.imageSchema().toString().contains("recognizedText"));
    assertTrue(schema.contains("maxLength=120"));
    assertTrue(schema.contains("maxLength=400"));
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
        anyString(), anyString(), anyString(), eq(1800), eq("homework_organization"), anyMap());
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
