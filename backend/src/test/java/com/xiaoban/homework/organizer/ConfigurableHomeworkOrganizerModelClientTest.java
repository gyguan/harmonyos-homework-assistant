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
  private static String migrationSql() {
    try (var stream = ConfigurableHomeworkOrganizerModelClientTest.class.getClassLoader()
        .getResourceAsStream("db/migration/V40__homework_organizer_rules.sql")) {
      if (stream == null) throw new IllegalStateException("V40 rules migration missing");
      return new String(stream.readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
    } catch (java.io.IOException error) {
      throw new IllegalStateException(error);
    }
  }

  private static String seededShorthand() {
    String sql = migrationSql();
    var pattern = java.util.regex.Pattern.compile(
        "'GLOBAL_SHORTHAND_[0-9]+'\\s*,\\s*'SHORTHAND'\\s*,"
        + "\\s*\\$seed\\$(.*?)\\$seed\\$\\s*,\\s*\\$seed\\$(.*?)\\$seed\\$\\s*,"
        + "\\s*\\$seed\\$(.*?)\\$seed\\$\\s*,\\s*\\$seed\\$(.*?)\\$seed\\$",
        java.util.regex.Pattern.DOTALL);
    var matcher = pattern.matcher(sql);
    var entries = new java.util.ArrayList<String>();
    while (matcher.find()) {
      entries.add(String.join("|", matcher.group(1), matcher.group(2), matcher.group(3), matcher.group(4)));
    }
    assertEquals(10, entries.size(), "Flyway must seed the full existing shorthand glossary");
    return String.join(";", entries);
  }

  private static String seededTemplate(String key) {
    var pattern = java.util.regex.Pattern.compile(
        "'PROMPT_" + key + "'\\s*,\\s*'PROMPT'\\s*,\\s*\\$seed\\$.*?\\$seed\\$"
        + "\\s*,\\s*\\$seed\\$(.*?)\\$seed\\$",
        java.util.regex.Pattern.DOTALL);
    var matcher = pattern.matcher(migrationSql());
    assertTrue(matcher.find(), "missing migrated template " + key);
    return matcher.group(1);
  }

  private static ConfigurableHomeworkOrganizerModelClient.ConversionResult seededCandidates(
      ConfigurableHomeworkOrganizerModelClient.StructuredResult result) {
    return ConfigurableHomeworkOrganizerModelClient.toCandidates(result, seededShorthand());
  }

  private static ConfigurableHomeworkOrganizerModelClient.ConversionResult seededCandidates(
      ConfigurableHomeworkOrganizerModelClient.StructuredResult result, String extra) {
    return ConfigurableHomeworkOrganizerModelClient.toCandidates(result, seededShorthand() + ";" + extra);
  }



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
        eq("data:image/jpeg;base64,PRIVATE"), eq(1800), anyString(), anyMap());

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
  void shorthandGlossaryExplainsTeacherAbbreviations() {
    // 老师（官士棋）惯用极简短写，模型按字面读会丢任务或理解错，
    // 例如「课外30分」被当成时长丢掉、「一起作业」被当成「一起做作业」。
    String section = ConfigurableHomeworkOrganizerModelClient.shorthandSection(seededShorthand());

    assertTrue(section.contains("一起作业"));
    assertTrue(section.contains("阅读绘本"), section);
    assertTrue(section.contains("听读U"));
    assertTrue(section.contains("课外阅读 30 分钟"));
    assertTrue(section.contains("国学"));
    assertTrue(section.contains("久久积累"));
    assertTrue(section.contains("订正《小白练》练习单"));
    // 同义简写并成一行：「绘本」「绘」
    assertTrue(section.contains("「绘本」「绘」＝阅读绘本"), section);
    // 数字占位符要渲染成人能读懂的形式，不能留 *
    assertFalse(section.contains("*"), section);
    assertTrue(section.contains("听读U＋数字"), section);
    // 必须要求把展开后的含义写进标题，而不是照抄简写
    assertTrue(section.contains("写进 title 和 instruction"));
  }

  @Test
  void shorthandGlossaryAppendsConfiguredEntriesWithoutDroppingBuiltins() {
    // 家长后续要加简写只改环境变量，不该动代码，也不该覆盖内置词条。
    String section = ConfigurableHomeworkOrganizerModelClient.shorthandSection(
        seededShorthand() + ";数学|口算|口算题卡;英语|周练|周末练习单");

    assertTrue(section.contains("数学："));
    assertTrue(section.contains("「口算」＝口算题卡"));
    assertTrue(section.contains("「周练」＝周末练习单"));
    assertTrue(section.contains("「绘本」"), "追加项不能覆盖内置词条");
    assertTrue(section.contains("课外阅读 30 分钟"));
  }

  @Test
  void teacherFormatSectionHandlesThreePartNotification() {
    // 官桐羽老师（语文）的通知固定分三段：学习进度 / 常规作业 / 今日作业。
    // 不写进提示词的话，模型会把「学习进度」当成一项作业、把常规作业的两项并成一条。
    String section = seededTemplate("THREE_PART");

    assertTrue(section.contains("学习进度"));
    assertTrue(section.contains("常规作业"));
    assertTrue(section.contains("今日作业"));
    assertTrue(section.contains("不要为它生成任务"), "学习进度不是作业，不能生成任务");
    assertTrue(section.contains("课外阅读 30 分钟"));
    assertTrue(section.contains("心情日记"));
    assertTrue(section.contains("必须先归纳"), "长描述要先归纳再定标题");
  }

  @Test
  void conversionNeverSilentlyDropsOrRewritesModelTasksByTeacherKeywords() {
    var result = seededCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", "今天我们学了《黄山奇石》。", "今天我们学了《黄山奇石》。",
                "语文书", null, 5, "学习进度：今天我们学了《黄山奇石》。", 0.9),
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", "朗读课文三遍", "朗读课文三遍，家长签字",
                "部编版", null, 15, "朗读课文三遍。", 0.9))), "");
    assertEquals(2, result.sourceCount());
    assertEquals(2, result.candidates().size());
    assertEquals("今天我们学了《黄山奇石》。", result.candidates().getFirst().title());
    assertEquals("朗读课文三遍", result.candidates().get(1).title());
  }

  @Test
  void readStructuredToleratesLineCommentsInsideJson() {
    // 模型偶尔在字段后面加解释性注释（"expectedMinutes": 30, // 大约需要30分钟），
    // 标准 JSON 不接受，会让整次整理解析失败并静默退回本地规则。
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), null, JsonMapper.builder().build());
    String output = """
        {"assignments":[
          {"subject":"英语","title":"听读课本第4单元课文",  // 单元来自 U4
           "instruction":"听读课本第4单元课文","textbookRef":"沪教版","taskDate":"今天",
           "expectedMinutes":10,"sourceExcerpt":"英语：1、听读课文U4/绘本，10分钟",
           "confidence":0.9}
        ]}
        """;

    var parsed = client.readStructured(output);

    assertEquals(1, parsed.assignments().size());
    assertEquals("英语", parsed.assignments().getFirst().subject());
    assertEquals("听读课本第4单元课文", parsed.assignments().getFirst().title());
  }

  @Test
  void englishTeacherFormatSectionHandlesEnglishNotification() {
    // 官桐羽 / 官士棋（同一位英语老师）的作业：条目少、简写重，
    // 一个序号里用「/」并列多个听读对象——写两点实际是三个任务；
    // 且绘本那一项由定时语音任务自动布置，整理结果里不能再出现。
    String section = seededTemplate("ENGLISH");

    assertTrue(section.contains("U＋数字"), "要说明 U 是 Unit 的缩写");
    assertTrue(section.contains("不要输出这一条任务"), "绘本由定时语音任务生成，不能重复产出");
    assertTrue(section.contains("序号点数不等于作业任务数"), "老师写两点可能是三个任务");
    assertTrue(section.contains("一起作业"));
  }

  @Test
  void blackboardFormatSectionHandlesNoticeBoardTable() {
    // 官士棋老师把作业写在黑板《作业公示栏》里：学科是行、内容在手写格子里、时长在独立列。
    // 不写进提示词时，模型会把表头当作业、把「其他」行的课外阅读归到阅读/其他。
    String section = seededTemplate("BLACKBOARD");

    assertTrue(section.contains("作业公示栏"));
    assertTrue(section.contains("预计时长"), "要说明时长列不是作业");
    assertTrue(section.contains("不是作业"), "表头与版式信息不能生成任务");
    assertTrue(section.contains("「其他」行不是新科目"));
    assertTrue(section.contains("跨行"), "日记跨行续写要合并，不能丢");
    assertTrue(section.contains("一起作业"), "一起作业不能跟着绘本被删掉");
    assertTrue(section.contains("不要拆成四条"), "按序号粒度，避免同一行时长被重复计算");
  }

  @Test
  void aiOutputSubjectsAreNotReclassifiedUsingTaskKeywords() {
    var result = seededCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "其他", "课外阅读30分钟", "阅读课外书30分钟", "", null, 20,
                "课外阅读30分钟", 0.8))));
    assertEquals("其他", result.candidates().getFirst().subject());
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("写作"));
    assertEquals("语文", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("语文"));
  }

  @Test
  void aiOutputIsKeptIntactWhilePromptDefinesVoiceAndShorthandPolicy() {
    String policy = seededTemplate("ENGLISH");
    assertTrue(policy.contains("绘本"));
    assertTrue(policy.contains("不要输出这一条任务"));

    var result = seededCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "英语", "听读课文U4/绘本，10分钟", "听读课本第4单元课文并阅读绘本",
                "沪教版", null, 10, "英语：1、听读课文U4/绘本，10分钟", 0.9),
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "英语", "一起作业", "在「一起作业」APP 上完成布置的作业",
                "沪教版", null, 15, "2、一起作业。", 0.9))), "");
    assertEquals(2, result.candidates().size());
    assertEquals("听读课文U4/绘本，10分钟", result.candidates().get(0).title());
    assertEquals("一起作业", result.candidates().get(1).title());
    assertEquals(2, result.sourceCount());

    var onlyBook = seededCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "英语", "绘本", "阅读绘本10分钟", "沪教版", null, 10,
                "绘本", 0.9))), "");
    assertEquals(1, onlyBook.candidates().size());
    assertEquals("绘本", onlyBook.candidates().getFirst().title());
  }

  @Test
  void mergedShorthandOutputIsNotFabricatedIntoNewTitlesInJava() {
    var result = seededCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "英语", "一起作业平台作业及听读课文U4",
                "在「一起作业」APP 上完成布置的作业，并听读课文U4", "英语课本",
                null, 30, "一起作业. 听读U4", 0.9))), "");
    assertEquals(1, result.candidates().size());
    assertEquals("一起作业平台作业及听读课文U4", result.candidates().getFirst().title());
  }

  @Test
  void keepsOneTaskWhenOnlyASingleShorthandMatches() {
    // 「预习8、10课 订小白」只有「订小白」一个简写，不能拆
    var result = seededCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", "预习8、10课 订小白",
                "预习第8、10课，订正《小白练》练习单", "语文书", null, 30,
                "2、预习8、10课 订小白", 0.9))),
        "");

    assertEquals(1, result.candidates().size());
    assertEquals("预习8、10课 订小白", result.candidates().get(0).title());
  }

  @Test
  void shorthandGlossaryIgnoresMalformedEntries() {
    String section = ConfigurableHomeworkOrganizerModelClient.shorthandSection(
        seededShorthand() + ";只有一项;|缺科目|缺含义;;数学||空简写");

    assertTrue(section.contains("课外阅读 30 分钟"), "非法条目不应影响内置词典");
    assertFalse(section.contains("只有一项"));
    assertFalse(section.contains("缺科目"));
    assertFalse(section.contains("空简写"));
  }

  @Test
  void splitsMergedNumberedItemsIntoOneTaskEach() {
    // 线上真实黑板图：语文格子里写了「1、复习P28-38 周一练习」「2、预习8、10课 订正小白张」，
    // glm-4.6v-flashx 把它们并成一条，第 2 点只剩在 instruction 里，家长直接漏做。
    var result = seededCandidates(
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
    var result = seededCandidates(
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
    var result = seededCandidates(
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
    var result = seededCandidates(
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
    var result = seededCandidates(
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
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("语文作业"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("Math"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("English Reading"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("阅读任务"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("朗诵练习"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("体育运动"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("劳动实践"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("兴趣拓展"));
    assertEquals("语文", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("语文"));
    assertEquals("阅读", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("阅读"));
    assertEquals("其他", ConfigurableHomeworkOrganizerModelClient.normalizeSubject("其他"));
    assertNull(ConfigurableHomeworkOrganizerModelClient.normalizeSubject("Science"));
  }

  @Test
  void conversionReportsRejectedAssignmentsAndClearsLegacyDuplicateFields() {
    var result = seededCandidates(
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
    // 输出长度就是家长等待时间：instruction 300 字、sourceExcerpt 120 字是刻意收紧的预算，
    // 放宽会让一次整理多花十几秒。
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
        anyString(), anyString(), anyString(), eq(2000), eq("homework_organization"), anyMap());
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
  @Test
  void sendsOnlyStudentTeacherScopedExperienceToTextModel() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    var experiences = mock(HomeworkTeacherExperienceService.class);
    var student = new TestStudent();
    student.id = "student-a";
    student.familyId = java.util.UUID.randomUUID();
    when(experiences.context(eq(student), eq("王老师：通知"), eq("朗读国13"), eq(false)))
        .thenReturn("老师「王老师」：国13 指《国学》第13页。");
    when(transport.complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap()))
        .thenReturn(java.util.Optional.of("{}"));
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), transport, JsonMapper.builder().build(), experiences);

    client.organize(student, "王老师：通知", "朗读国13");

    var instructions = org.mockito.ArgumentCaptor.forClass(String.class);
    verify(transport).complete(anyString(), instructions.capture(), anyString(), anyInt(), anyString(), anyMap());
    assertTrue(instructions.getValue().contains("国13 指《国学》第13页"));
  }

  @Test
  void missingAndOutOfRangeDurationsUseDeterministicSafeValues() {
    var result = seededCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文", "书写汉字", "书写汉字一行", "", null, null,
                "语文书写汉字", 0.9),
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "数学", "练习口算", "完成口算题", "", null, 1000,
                "数学口算练习", 0.9),
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "英语", "复习单词", "默读单词清单", "", null, -5,
                "英语单词清单", 0.9))));
    assertEquals(List.of(20, 120, 20),
        result.candidates().stream().map(HomeworkOrganizerDtos.Candidate::expectedMinutes).toList());
  }

  @Test
  void confirmedExperienceTriggersAiReviewRatherThanJavaKeywordRewrite() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    var experiences = mock(HomeworkTeacherExperienceService.class);
    var student = new TestStudent();
    student.id = "student-review";
    student.familyId = java.util.UUID.randomUUID();
    String original = "语文：摘抄：（3+2）";
    String experience = "家长经验：摘抄中两个数字分别表示本次好词、好句数量。";
    when(experiences.context(eq(student), eq("家长文字"), eq(original), eq(false)))
        .thenReturn(experience);
    when(transport.complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap()))
        .thenAnswer(inv -> {
          String scene = inv.getArgument(4);
          if ("homework_experience_review".equals(scene)) {
            return java.util.Optional.of("""
                {"assignments":[{"subject":"语文","title":"摘抄3个好词、2个好句",
                "instruction":"摘抄3个好词、2个好句","textbookRef":"待家长确认",
                "taskDate":"2026-10-19","expectedMinutes":15,
                "sourceExcerpt":"摘抄：（3+2）","confidence":0.95}]}
                """);
          }
          return java.util.Optional.of("""
              {"assignments":[{"subject":"语文","title":"完成摘抄（3+2）",
              "instruction":"完成摘抄（3+2）","textbookRef":"待家长确认",
              "taskDate":"2026-10-19","expectedMinutes":15,
              "sourceExcerpt":"摘抄：（3+2）","confidence":0.95}]}
              """);
        });
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), transport, JsonMapper.builder().build(), experiences);
    var result = client.organize(student, "家长文字", original).orElseThrow();
    assertEquals("摘抄3个好词、2个好句", result.getFirst().title());
    var prompts = org.mockito.ArgumentCaptor.forClass(String.class);
    verify(transport, org.mockito.Mockito.times(2)).complete(anyString(), prompts.capture(),
        anyString(), anyInt(), anyString(), anyMap());
    assertTrue(prompts.getAllValues().get(1).contains("质量复核"));
    assertTrue(prompts.getAllValues().get(1).contains(experience));
  }

  @Test
  void aiReviewFailureDoesNotInventUnconfirmedCorrection() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    var experiences = mock(HomeworkTeacherExperienceService.class);
    var student = new TestStudent();
    student.id = "student-review-fail";
    student.familyId = java.util.UUID.randomUUID();
    when(experiences.context(eq(student), anyString(), anyString(), eq(false)))
        .thenReturn("家长经验：需按原文解释");
    when(transport.complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap()))
        .thenAnswer(inv -> "homework_experience_review".equals(inv.getArgument(4))
            ? java.util.Optional.empty()
            : java.util.Optional.of("""
                {"assignments":[{"subject":"语文","title":"完成摘抄（3+2）",
                "instruction":"完成摘抄（3+2）","textbookRef":"待家长确认",
                "taskDate":"2026-10-19","expectedMinutes":15,
                "sourceExcerpt":"摘抄：（3+2）","confidence":0.95}]}
                """));
    var client = new ConfigurableHomeworkOrganizerModelClient(
        new AiProviderProperties(), transport, JsonMapper.builder().build(), experiences);
    var result = client.organize(student, "家长文字", "语文：摘抄：（3+2）").orElseThrow();
    assertEquals("完成摘抄（3+2）", result.getFirst().title());
  }


}
