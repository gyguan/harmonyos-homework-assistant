package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeGenerationModelClientParsingTest {
  @Test
  void usesJsonObjectAsPrimaryModeForChatCompletions() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setProtocol("chat-completions");
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    String canonicalOutput = """
        {
          "questions": [
            {
              "type": "NUMBER",
              "stem": "14 - 6 = ?",
              "options": [],
              "answerSpec": "8",
              "explanation": "14减6等于8。",
              "hints": ["关键词：14、减6"],
              "tags": ["减法"]
            }
          ]
        }
        """;

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        eq(PracticeGenerationModelClient.jsonObjectInstructions()),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class),
        eq(OpenAiCompatibleTransport.StructuredOutputMode.JSON_OBJECT)))
        .thenReturn(Optional.of(canonicalOutput));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-chat-json-object",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习退位减法"));

    assertTrue(result.isPresent());
    assertEquals("14 - 6 = ?", result.get().questions().get(0).stem());

    verify(transport).complete(
        eq("deepseek-v4-flash-0731"),
        eq(PracticeGenerationModelClient.jsonObjectInstructions()),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class),
        eq(OpenAiCompatibleTransport.StructuredOutputMode.JSON_OBJECT));
  }

  @Test
  void retriesJsonObjectWhenSchemaRequestReturnsEmpty() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        eq(PracticeGenerationModelClient.instructions()),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class)))
        .thenReturn(Optional.empty());

    String canonicalRetryOutput = """
        {
          "questions": [
            {
              "type": "NUMBER",
              "stem": "13 - 5 = ?",
              "options": [],
              "answerSpec": "8",
              "explanation": "13减5等于8。",
              "hints": ["关键词：13、减5"],
              "tags": ["减法"]
            }
          ]
        }
        """;
    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        eq(PracticeGenerationModelClient.jsonObjectInstructions()),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class),
        eq(OpenAiCompatibleTransport.StructuredOutputMode.JSON_OBJECT)))
        .thenReturn(Optional.of(canonicalRetryOutput));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-empty-schema-retry",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习退位减法"));

    assertTrue(result.isPresent());
    assertEquals("8", result.get().questions().get(0).answerSpec());
  }

  @Test
  void retriesWithJsonObjectWhenSchemaOutputIsStructurallyInvalid() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    String invalidSchemaOutput = """
        {
          "questions": [
            {
              "type": "NUMBER",
              "question": "12 - 5 = ?",
              "options": [],
              "answerSpec": "7",
              "explanation": "12减5等于7。",
              "hints": ["关键词：12、减5"],
              "tags": ["减法"]
            }
          ]
        }
        """;
    String canonicalRetryOutput = """
        {
          "questions": [
            {
              "type": "NUMBER",
              "stem": "12 - 5 = ?",
              "options": [],
              "answerSpec": "7",
              "explanation": "12减5等于7。",
              "hints": ["关键词：12、减5"],
              "tags": ["减法"]
            }
          ]
        }
        """;

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        eq(PracticeGenerationModelClient.instructions()),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class)))
        .thenReturn(Optional.of(invalidSchemaOutput));

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        eq(PracticeGenerationModelClient.jsonObjectInstructions()),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class),
        eq(OpenAiCompatibleTransport.StructuredOutputMode.JSON_OBJECT)))
        .thenReturn(Optional.of(canonicalRetryOutput));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-negotiated-output",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习退位减法"));

    assertTrue(result.isPresent());
    assertEquals("12 - 5 = ?", result.get().questions().get(0).stem());
    assertEquals("7", result.get().questions().get(0).answerSpec());

    verify(transport).complete(
        eq("deepseek-v4-flash-0731"),
        eq(PracticeGenerationModelClient.jsonObjectInstructions()),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class),
        eq(OpenAiCompatibleTransport.StructuredOutputMode.JSON_OBJECT));
  }

  @Test
  void parsesQuestionsOnlyRootAndBuildsPaperMetadataFromRequest() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    String output = """
        ```json
        {
          "questions": [
            {
              "type": "NUMBER",
              "stem": "12 - 5 = ?",
              "options": [],
              "answerSpec": "7",
              "explanation": "12减5等于7。",
              "hints": ["关键词：12、减5"],
              "tags": ["减法"]
            }
          ]
        }
        ```
        """;

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        any(String.class),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class)))
        .thenReturn(Optional.of(output));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-questions-only",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习退位减法"));

    assertTrue(result.isPresent());
    assertEquals("练习退位减法", result.get().title());
    assertEquals("AI根据家长训练要求生成的数学教材同步练习", result.get().description());
    assertEquals(5, result.get().estimatedMinutes());
    assertEquals("7", result.get().questions().get(0).answerSpec());
  }

  @Test
  void schemaRequiresOnlyQuestionsAtTopLevel() {
    Map<String, Object> schema = PracticeGenerationModelClient.schema(5);

    Map<?, ?> properties = (Map<?, ?>) schema.get("properties");
    assertEquals(1, properties.size());
    assertTrue(properties.containsKey("questions"));
    assertEquals(java.util.List.of("questions"), schema.get("required"));
  }

  @Test
  void parsesMarkdownAndPaperWrapperFromCompatibleProvider() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    String paperJson = """
        {
          "title": "100以内减法",
          "description": "退位减法专项",
          "estimatedMinutes": 10,
          "tags": ["退位减法"],
          "questions": [
            {
              "type": "NUMBER",
              "stem": "41 - 5 = ?",
              "options": [],
              "answerSpec": "36",
              "explanation": "41减5等于36。",
              "hints": ["关键词：41、减5"],
              "tags": ["退位减法"]
            }
          ]
        }
        """;
    String wrapped = "```json\n{\"paper\":" + paperJson + "}\n```";

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        any(String.class),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class)))
        .thenReturn(Optional.of(wrapped));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-test",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习退位减法"));

    assertTrue(result.isPresent());
    assertEquals("100以内减法", result.get().title());
    assertEquals(1, result.get().questions().size());
    assertEquals("36", result.get().questions().get(0).answerSpec());
  }

  @Test
  void parsesObjectWrappedScalarFieldsFromDeepSeekCompatibleProvider() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    String output = """
        {
          "title": {"text": "退位减法练习"},
          "description": {"value": "专项练习"},
          "estimatedMinutes": {"value": 8},
          "tags": [{"text": "退位减法"}],
          "questions": [
            {
              "type": {"value": "NUMBER"},
              "stem": {"text": "41 - 5 = ?"},
              "options": [],
              "answerSpec": {"answer": {"value": 36}},
              "explanation": {"text": "41减5等于36。"},
              "hints": [{"text": "关键词：41、减5"}],
              "tags": [{"text": "退位减法"}]
            }
          ]
        }
        """;

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        any(String.class),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class)))
        .thenReturn(Optional.of(output));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-object-fields",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习退位减法"));

    assertTrue(result.isPresent());
    assertEquals("退位减法练习", result.get().title());
    assertEquals("36", result.get().questions().get(0).answerSpec());
    assertEquals("关键词：41、减5", result.get().questions().get(0).hints().get(0));
  }

  @Test
  void parsesFencedUnknownPaperEnvelopeFromCompatibleProvider() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    String output = """
        ```json
        {
          "practicePayload": {
            "title": "20以内加法",
            "description": "生活化加法练习",
            "estimatedMinutes": 8,
            "tags": ["加法"],
            "questions": [
              {
                "type": "NUMBER",
                "stem": "8 + 7 = ?",
                "options": [],
                "answerSpec": "15",
                "explanation": "8加7等于15。",
                "hints": ["关键词：8、加7"],
                "tags": ["加法"]
              }
            ]
          }
        }
        ```
        """;

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        any(String.class),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class)))
        .thenReturn(Optional.of(output));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-generic-envelope",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习20以内加法"));

    assertTrue(result.isPresent());
    assertEquals("20以内加法", result.get().title());
    assertEquals("15", result.get().questions().get(0).answerSpec());
  }

  @Test
  void parsesFencedStringAndSingletonArrayEnvelopeFromCompatibleProvider() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    String canonical = """
        {
          "title": "20以内加法",
          "description": "生活化加法练习",
          "estimatedMinutes": 8,
          "tags": ["加法"],
          "questions": [
            {
              "type": "NUMBER",
              "stem": "9 + 6 = ?",
              "options": [],
              "answerSpec": "15",
              "explanation": "9加6等于15。",
              "hints": ["关键词：9、加6"],
              "tags": ["加法"]
            }
          ]
        }
        """;
    String encodedCanonical = mapper.writeValueAsString(canonical);
    String output = "```json\n{\"providerPayload\":[{\"content\":" + encodedCanonical + "}]}\n```";

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        any(String.class),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class)))
        .thenReturn(Optional.of(output));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-envelope-values",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习20以内加法"));

    assertTrue(result.isPresent());
    assertEquals("20以内加法", result.get().title());
    assertEquals("15", result.get().questions().get(0).answerSpec());
  }

  @Test
  void adaptsProviderStringOptionsAndAnswerLabelBeforeDomainMapping() throws Exception {
    AiProviderProperties properties = new AiProviderProperties();
    properties.setTutorModel("deepseek-v4-flash-0731");
    properties.setPracticeModel("");

    OpenAiCompatibleTransport transport = mock(OpenAiCompatibleTransport.class);
    JsonMapper mapper = JsonMapper.builder().build();

    String output = """
        {
          "title": "生活加法练习",
          "description": "练习简单加法",
          "estimatedMinutes": 8,
          "tags": ["加法"],
          "questions": [
            {
              "type": "single-choice",
              "stem": "小明有5元，又得到1元，一共有多少元？",
              "options": ["5元", "6元", "7元"],
              "answerSpec": "6元",
              "explanation": "5加1等于6。",
              "hints": ["关键词：5元、又得到1元"],
              "tags": ["加法"]
            }
          ]
        }
        """;

    when(transport.complete(
        eq("deepseek-v4-flash-0731"),
        any(String.class),
        any(String.class),
        eq(7000),
        eq("practice_generation"),
        any(Map.class)))
        .thenReturn(Optional.of(output));

    PracticeGenerationModelClient client =
        new PracticeGenerationModelClient(properties, transport, mapper);

    Optional<PracticeContentCatalog.Paper> result = client.generate(
        "人教版数学二年级上册",
        "ai-string-options",
        "G2",
        "S1",
        new PracticeGenerationDtos.GenerateRequest(
            "MATH", "TEXTBOOK_SYNC", "L1", 1, "练习简单加法"));

    assertTrue(result.isPresent());
    PracticeContentCatalog.Question question = result.get().questions().get(0);
    assertEquals("SINGLE_CHOICE", question.type());
    assertEquals("A", question.options().get(0).key());
    assertEquals("B", question.options().get(1).key());
    assertEquals("6元", question.options().get(1).label());
    assertEquals("B", question.answerSpec());
  }

}
