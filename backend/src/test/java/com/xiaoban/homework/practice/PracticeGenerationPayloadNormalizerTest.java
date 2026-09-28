package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeGenerationPayloadNormalizerTest {
  private final JsonMapper mapper = JsonMapper.builder().build();

  @Test
  void unwrapsKnownScalarObjectsAcrossPaperQuestionAndOptionFields() throws Exception {
    String input = """
        {
          "title": {"text": "100以内减法"},
          "description": {"value": "退位减法专项"},
          "estimatedMinutes": {"value": "10"},
          "tags": [{"text": "退位减法"}],
          "questions": [
            {
              "type": {"value": "SINGLE_CHOICE"},
              "stem": {"text": "41 - 5 = ?"},
              "options": [
                {"key": {"value": "A"}, "label": {"text": "36"}},
                {"key": {"value": "B"}, "label": {"text": "37"}},
                {"key": {"value": "C"}, "label": {"text": "38"}}
              ],
              "answerSpec": {"answer": {"value": "A"}},
              "explanation": {"content": "41减5等于36。"},
              "hints": [{"text": "关键词：41、减5"}],
              "tags": [{"value": "退位减法"}]
            }
          ]
        }
        """;

    PracticeGenerationPayloadNormalizer.Result result =
        PracticeGenerationPayloadNormalizer.normalize(mapper, input);

    Map<?, ?> root = mapper.readValue(result.json(), Map.class);
    assertEquals("100以内减法", root.get("title"));
    assertEquals(10, root.get("estimatedMinutes"));

    List<?> questions = (List<?>) root.get("questions");
    Map<?, ?> question = (Map<?, ?>) questions.get(0);
    assertEquals("SINGLE_CHOICE", question.get("type"));
    assertEquals("A", question.get("answerSpec"));

    List<?> options = (List<?>) question.get("options");
    Map<?, ?> firstOption = (Map<?, ?>) options.get(0);
    assertEquals("36", firstOption.get("label"));

    assertTrue(result.coercedPaths().contains("$.title"));
    assertTrue(result.coercedPaths().contains("$.estimatedMinutes"));
    assertTrue(result.coercedPaths().contains("$.questions[0].answerSpec"));
    assertTrue(result.coercedPaths().contains("$.questions[0].options[0].label"));
  }

  @Test
  void leavesUnknownComplexObjectUntouchedForTypedMapperToReject() throws Exception {
    String input = """
        {
          "title": {"left": "A", "right": "B"},
          "description": "测试",
          "estimatedMinutes": 10,
          "tags": ["测试"],
          "questions": []
        }
        """;

    PracticeGenerationPayloadNormalizer.Result result =
        PracticeGenerationPayloadNormalizer.normalize(mapper, input);

    Map<?, ?> root = mapper.readValue(result.json(), Map.class);
    assertTrue(root.get("title") instanceof Map<?, ?>);
  }
}
