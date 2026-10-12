package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.ai.AiProviderProperties;
import tools.jackson.databind.json.JsonMapper;
import java.time.LocalDate;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;

class ConfigurableHomeworkOrganizerModelClientTest {
  @Test
  void submitsSupplementaryTextAlongsideImageAndKeepsItOutOfInstructions() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    when(transport.completeWithImage(anyString(), anyString(), anyString(), anyString(), anyInt(),
        anyString(), anyMap())).thenReturn(java.util.Optional.of(
            "{\"recognizedText\":\"语文朗读\",\"assignments\":[]} "));
    var client = new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(), transport,
        JsonMapper.builder().build());
    client.organizeImage(new TestStudent(), "相册", "data:image/jpeg;base64,PRIVATE", " 数学口算20题 ");
    var instructions = org.mockito.ArgumentCaptor.forClass(String.class);
    var input = org.mockito.ArgumentCaptor.forClass(String.class);
    verify(transport).completeWithImage(anyString(), instructions.capture(), input.capture(),
        eq("data:image/jpeg;base64,PRIVATE"), eq(6000), anyString(), anyMap());
    assertTrue(input.getValue().contains("补充文字（可能为空）：\n数学口算20题"));
    assertTrue(instructions.getValue().contains("sameTaskGroup"));
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
    var client = new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(), transport,
        JsonMapper.builder().build());
    var error = assertThrows(com.xiaoban.homework.common.ApiExceptions.ServiceUnavailable.class,
        () -> client.organizeImage(new TestStudent(), "相册", "data:image/jpeg;base64,PRIVATE", null));
    assertTrue(error.getMessage().contains("HTTP 406"));
    assertTrue(error.getMessage().contains("data URL"));
    assertFalse(error.getMessage().contains("PRIVATE"));
  }

  @Test
  void imageResultKeepsMultipleSubjectsAndRejectsIncompleteOutput() {
    var client = new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(), null,
        JsonMapper.builder().build());
    String output = """
        {"recognizedText":"语文背诵；数学口算", "assignments":[
          {"subject":"语文","title":"背诵","instruction":"背诵课文","expectedMinutes":10,"confidence":0.9},
          {"subject":"数学","title":"口算","instruction":"口算20题","expectedMinutes":15,"confidence":0.8}
        ]}
        """;
    var result = client.parseImageOutput(output).orElseThrow();
    assertEquals(java.util.List.of("语文", "数学"), result.assignments().stream()
        .map(HomeworkOrganizerDtos.Candidate::subject).toList());
    assertEquals("语文背诵；数学口算", result.recognizedText());
    assertTrue(client.parseImageOutput(output.replace("\"recognizedText\"", "\"unused\"")).isEmpty());
    assertTrue(client.parseImageOutput(output.replace("\"数学\"", "\"InvalidSubject\"")).isEmpty());
    assertTrue(client.parseImageOutput("{\"recognizedText\":\"班级通知\",\"assignments\":[]}")
        .orElseThrow().assignments().isEmpty());
  }
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
                "科学", "观察植物", "观察并记录", "", "今天", 20, "观察植物", 0.9,
                "", "", 0.0, ""),
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "语文作业", "背诵第12课", "背诵课文", "", "明天", 15, "背诵第12课", 0.95,
                "", "", 0.0, ""))));

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
    assertTrue(schema.contains("sameTaskGroup"));
    assertFalse(schema.contains("duplicateAssignmentId"));
    assertFalse(schema.contains("duplicateConfidence"));
    assertFalse(schema.contains("duplicateReason"));
  }

  @Test
  void historicalAssignmentsStayOutOfAiPromptAndModelDuplicateHintsAreIgnored() {
    TestStudent student = new TestStudent();
    student.grade = "二年级";
    var existing = java.util.List.of(new HomeworkOrganizerDtos.ExistingAssignment(
        "a-existing-1", "数学", "练习册 P26 第1～6题", "完成后订正", "北师大版", "今天", 0L,
        "数学练习册第26页1-6题，完成后订正"));

    String input = ConfigurableHomeworkOrganizerModelClient.buildInput(
        student, "老师通知", "数学第三单元练习第26页1到6题", existing);
    assertTrue(input.contains("数学第三单元练习第26页1到6题"));
    assertFalse(input.contains("a-existing-1"));
    assertFalse(input.contains("当前已有任务"));
    assertFalse(input.contains("数学练习册第26页1-6题，完成后订正"));

    var converted = ConfigurableHomeworkOrganizerModelClient.toCandidates(
        new ConfigurableHomeworkOrganizerModelClient.StructuredResult(java.util.List.of(
            new ConfigurableHomeworkOrganizerModelClient.StructuredCandidate(
                "数学", "数学第三单元练习", "第26页1到6题，完成后订正", "", "今天", 20,
                "数学第三单元练习第26页1到6题", 0.95, "G1", "a-existing-1", 0.93,
                "模型不再负责历史任务重复判断"))),
        java.util.Map.of("a-existing-1", "练习册 P26 第1～6题"));
    assertEquals("G1", converted.candidates().getFirst().sameTaskGroup());
    assertEquals("", converted.candidates().getFirst().duplicateAssignmentId());
    assertEquals(0.0, converted.candidates().getFirst().duplicateConfidence());
  }

  @Test
  void textOrganizerUsesCompactPromptAndFourteenHundredTokenBudget() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    when(transport.complete(anyString(), anyString(), anyString(), anyInt(), anyString(), anyMap()))
        .thenReturn(java.util.Optional.of("""
            {"assignments":[{"subject":"数学","title":"口算20题","instruction":"完成口算20题",
            "textbookRef":"","dueText":"今天","expectedMinutes":10,"sourceExcerpt":"口算20题",
            "confidence":0.95,"sameTaskGroup":""}]}
            """));
    var client = new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(), transport,
        JsonMapper.builder().build());

    var result = client.organize(new TestStudent(), "老师通知", "数学：口算20题").orElseThrow();
    assertEquals(1, result.size());

    var instructions = org.mockito.ArgumentCaptor.forClass(String.class);
    var input = org.mockito.ArgumentCaptor.forClass(String.class);
    verify(transport).complete(anyString(), instructions.capture(), input.capture(), eq(1400),
        eq("homework_organization"), anyMap());
    assertFalse(instructions.getValue().contains("duplicateAssignmentId"));
    assertFalse(instructions.getValue().contains("历史任务"));
    assertFalse(input.getValue().contains("当前已有任务"));
  }

  @Test
  void secondStageAiReviewsOnlyTodaySameSubjectAndReturnsCompactDuplicateMapping() {
    var transport = mock(com.xiaoban.homework.ai.OpenAiCompatibleTransport.class);
    when(transport.complete(anyString(), anyString(), anyString(), eq(800),
        eq("homework_duplicate_review"), anyMap()))
        .thenReturn(java.util.Optional.of("""
            {"matches":[{"candidateIndex":0,"duplicateAssignmentId":"a-math",
            "confidence":0.91,"reason":"页码题号和订正要求一致"}]}
            """));
    var client = new ConfigurableHomeworkOrganizerModelClient(new AiProviderProperties(), transport,
        JsonMapper.builder().build());

    var candidates = java.util.List.of(
        new HomeworkOrganizerDtos.Candidate(
            "数学", "第三单元练习", "第26页1到6题，完成后订正", "", "今天", 20,
            "第26页1到6题，完成后订正", 0.95, "", "", "", 0.0, ""),
        new HomeworkOrganizerDtos.Candidate(
            "语文", "背诵第12课", "背诵课文", "", "明天", 15,
            "背诵第12课", 0.9, "", "", "", 0.0, ""));
    var existing = java.util.List.of(
        new HomeworkOrganizerDtos.ExistingAssignment(
            "a-math", "数学", "练习册P26 1-6题", "完成后订正", "", "今天", 0L,
            "数学练习册第26页1-6题"),
        new HomeworkOrganizerDtos.ExistingAssignment(
            "a-english", "英语", "听读第3课", "听读第3课", "", "今天", 0L, "听读第3课"));

    var reviewed = client.reviewDuplicates(
        candidates, existing, "数学第三单元练习第26页1到6题").orElseThrow();

    assertEquals("a-math", reviewed.get(0).duplicateAssignmentId());
    assertEquals(0.91, reviewed.get(0).duplicateConfidence());
    assertEquals("", reviewed.get(1).duplicateAssignmentId());

    var instructions = org.mockito.ArgumentCaptor.forClass(String.class);
    var input = org.mockito.ArgumentCaptor.forClass(String.class);
    verify(transport).complete(anyString(), instructions.capture(), input.capture(), eq(800),
        eq("homework_duplicate_review"), anyMap());
    assertTrue(instructions.getValue().contains("只判断"));
    assertTrue(instructions.getValue().contains("字段名必须严格使用 candidateIndex、duplicateAssignmentId、confidence、reason"));
    assertTrue(instructions.getValue().contains("\"matches\":[]"));
    assertTrue(input.getValue().contains("candidateIndex=0"));
    assertTrue(input.getValue().contains("duplicateAssignmentId=a-math"));
    assertFalse(input.getValue().contains("\n- C0"));
    assertFalse(input.getValue().contains("\n- ID=a-math"));
    assertFalse(input.getValue().contains("a-english"));
    assertFalse(input.getValue().contains("背诵第12课"));
  }

  @Test
  void aiDuplicateResultIsValidatedButNotOverriddenByLocalSimilarityRules() {
    var candidates = java.util.List.of(new HomeworkOrganizerDtos.Candidate(
        "语文", "朗读第2课", "朗读第2课", "", "今天", 10,
        "朗读第2课", 0.9, "", "", "", 0.0, ""));
    var existing = java.util.List.of(
        new HomeworkOrganizerDtos.ExistingAssignment(
            "a-read", "语文", "朗读第2课", "朗读第2课", "", "今天", 0L, "朗读第2课"),
        new HomeworkOrganizerDtos.ExistingAssignment(
            "a-recite", "语文", "背诵第2课", "背诵第2课", "", "今天", 0L, "背诵第2课"));
    var review = new ConfigurableHomeworkOrganizerModelClient.DuplicateReviewResult(java.util.List.of(
        new ConfigurableHomeworkOrganizerModelClient.DuplicateDecision(
            0, "a-read", 0.88, "核心动作和课次一致")));

    var reviewed = ConfigurableHomeworkOrganizerModelClient.applyAiDuplicateDecisions(
        candidates, existing, review);

    assertEquals("a-read", reviewed.getFirst().duplicateAssignmentId());
    assertEquals(0.88, reviewed.getFirst().duplicateConfidence());
    assertTrue(reviewed.getFirst().duplicateReason().contains("核心动作"));
  }

  @Test
  void fallsBackToPublishedEvidenceWhenModelMissesDuplicateHint() {
    var existing = java.util.List.of(
        new HomeworkOrganizerDtos.ExistingAssignment(
            "a-existing-1", "数学", "练习册 P26 第1～6题", "完成后订正", "北师大版", "今天", 0L,
            "数学练习册第26页1-6题，完成后订正"),
        new HomeworkOrganizerDtos.ExistingAssignment(
            "a-existing-old", "语文", "背诵第12课", "背诵第12课", "", "今天", 0L, ""));

    var candidates = java.util.List.of(
        new HomeworkOrganizerDtos.Candidate(
            "数学", "数学第三单元练习", "第26页1到6题，完成后订正", "", "今天", 20,
            "数学练习册第26页1到6题，完成后订正", 0.95, "", "", "", 0.0, ""),
        new HomeworkOrganizerDtos.Candidate(
            "语文", "背诵第12课", "背诵第12课", "", "今天", 15,
            "背诵第12课", 0.9, "", "", "", 0.0, ""));

    var reviewed = ConfigurableHomeworkOrganizerModelClient.applyEvidenceDuplicateFallback(
        candidates, existing);

    assertEquals("a-existing-1", reviewed.get(0).duplicateAssignmentId());
    assertEquals(1.0, reviewed.get(0).duplicateConfidence());
    assertTrue(reviewed.get(0).duplicateReason().contains("老师原文"));

    assertEquals("a-existing-old", reviewed.get(1).duplicateAssignmentId());
    assertEquals(1.0, reviewed.get(1).duplicateConfidence());
    assertTrue(reviewed.get(1).duplicateReason().contains("标题"));
  }

  @Test
  void sourceInputFallbackDetectsSameTomorrowHomeworkEvenWhenModelMissesIt() {
    var existing = java.util.List.of(new HomeworkOrganizerDtos.ExistingAssignment(
        "a-tomorrow", "数学", "练习册 P26 第1～6题", "完成后订正", "", "明天", 0L,
        "数学练习册第26页1-6题，完成后订正"));
    var candidates = java.util.List.of(new HomeworkOrganizerDtos.Candidate(
        "数学", "数学第三单元练习", "第26页1到6题，完成后订正", "", "明日", 20,
        "第26页1到6题", 0.95, "", "", "", 0.0, ""));

    var reviewed = ConfigurableHomeworkOrganizerModelClient.applySourceInputDuplicateFallback(
        candidates, existing, "数学练习册第26页1到6题，完成后订正");

    assertEquals("a-tomorrow", reviewed.getFirst().duplicateAssignmentId());
    assertEquals(1.0, reviewed.getFirst().duplicateConfidence());
    assertTrue(reviewed.getFirst().duplicateReason().contains("同一份作业原文"));
  }

  @Test
  void removesModelDuplicateHintWhenCompletionDateDiffers() {
    var existing = java.util.List.of(new HomeworkOrganizerDtos.ExistingAssignment(
        "a-today", "数学", "口算20题", "完成口算20题", "", "今天", 0L, "口算20题"));
    var candidates = java.util.List.of(new HomeworkOrganizerDtos.Candidate(
        "数学", "口算20题", "完成口算20题", "", "明天", 10,
        "口算20题", 0.95, "", "a-today", "口算20题", 0.98, "内容一致"));

    var reviewed = ConfigurableHomeworkOrganizerModelClient.enforceSameDueForModelHints(
        candidates, existing);

    assertEquals("", reviewed.getFirst().duplicateAssignmentId());
    assertEquals(0.0, reviewed.getFirst().duplicateConfidence());
  }

  @Test
  void resolvesDifferentDueTextFormsToSameShanghaiBusinessDate() {
    LocalDate tomorrow = LocalDate.now(ZoneId.of("Asia/Shanghai")).plusDays(1);
    String explicit = tomorrow.toString();
    assertEquals(
        ConfigurableHomeworkOrganizerModelClient.candidateDueDate("明天"),
        ConfigurableHomeworkOrganizerModelClient.candidateDueDate(explicit));
    assertEquals(
        ConfigurableHomeworkOrganizerModelClient.candidateDueDate("明日"),
        ConfigurableHomeworkOrganizerModelClient.candidateDueDate(
            tomorrow.getMonthValue() + "月" + tomorrow.getDayOfMonth() + "日"));
  }

  @Test
  void legacyTaskWithoutSourceEvidenceCanStillMatchByStructuredSimilarity() {
    var existing = java.util.List.of(new HomeworkOrganizerDtos.ExistingAssignment(
        "a-legacy", "数学", "数学练习册 P26 1-6题", "完成后订正", "", "今天", 0L, ""));
    var candidates = java.util.List.of(new HomeworkOrganizerDtos.Candidate(
        "数学", "数学第三单元练习第26页1到6题", "完成后订正", "", "今天", 20,
        "第26页1到6题，完成后订正", 0.95, "", "", "", 0.0, ""));

    var reviewed = ConfigurableHomeworkOrganizerModelClient.applyEvidenceDuplicateFallback(
        candidates, existing);

    assertEquals("a-legacy", reviewed.getFirst().duplicateAssignmentId());
    assertEquals(1.0, reviewed.getFirst().duplicateConfidence());
    assertTrue(reviewed.getFirst().duplicateReason().contains("高度相似"));
  }

  @Test
  void evidenceFallbackDoesNotMergeDifferentActionsOrDueDates() {
    var existing = java.util.List.of(new HomeworkOrganizerDtos.ExistingAssignment(
        "a-read", "语文", "朗读第2课", "朗读第2课", "", "今天", 0L, "朗读第2课"));
    var candidates = java.util.List.of(
        new HomeworkOrganizerDtos.Candidate(
            "语文", "背诵第2课", "背诵第2课", "", "今天", 15,
            "背诵第2课", 0.9, "", "", "", 0.0, ""),
        new HomeworkOrganizerDtos.Candidate(
            "语文", "朗读第2课", "朗读第2课", "", "明天", 15,
            "朗读第2课", 0.9, "", "", "", 0.0, ""));

    var reviewed = ConfigurableHomeworkOrganizerModelClient.applyEvidenceDuplicateFallback(
        candidates, existing);

    assertEquals("", reviewed.get(0).duplicateAssignmentId());
    assertEquals("", reviewed.get(1).duplicateAssignmentId());
  }
}
