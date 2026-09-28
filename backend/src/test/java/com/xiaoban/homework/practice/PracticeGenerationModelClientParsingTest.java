package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.ai.AiProviderProperties;
import com.xiaoban.homework.ai.OpenAiCompatibleTransport;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeGenerationModelClientParsingTest {
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
}
