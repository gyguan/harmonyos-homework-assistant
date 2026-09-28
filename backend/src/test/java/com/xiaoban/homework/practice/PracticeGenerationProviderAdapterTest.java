package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeGenerationProviderAdapterTest {
  private final JsonMapper mapper = JsonMapper.builder().build();

  @Test
  void keepsStandardObjectOptionsAsCanonicalContract() throws Exception {
    String input = paperWithQuestion("""
        {
          "type": "SINGLE_CHOICE",
          "stem": "小明有5元，又得到1元，一共有多少元？",
          "options": [
            {"key": "A", "label": "5元"},
            {"key": "B", "label": "6元"},
            {"key": "C", "label": "7元"}
          ],
          "answerSpec": "B",
          "explanation": "5加1等于6。",
          "hints": ["关键词：5元、又得到1元"],
          "tags": ["加法"]
        }
        """);

    PracticeGenerationProviderAdapter.Result result =
        PracticeGenerationProviderAdapter.adapt(mapper, input);

    PracticeGenerationCanonicalContract.Question question = result.paper().questions().get(0);
    assertEquals("SINGLE_CHOICE", question.type());
    assertEquals("B", question.answerSpec());
    assertEquals("A", question.options().get(0).key());
    assertEquals("5元", question.options().get(0).label());
  }

  @Test
  void adaptsStringOptionsAndAnswerLabelToCanonicalKey() throws Exception {
    String input = paperWithQuestion("""
        {
          "type": "single-choice",
          "stem": "小明有5元，又得到1元，一共有多少元？",
          "options": ["5元", "6元", "7元"],
          "answerSpec": "6元",
          "explanation": "5加1等于6。",
          "hints": ["关键词：5元、又得到1元"],
          "tags": ["加法"]
        }
        """);

    PracticeGenerationProviderAdapter.Result result =
        PracticeGenerationProviderAdapter.adapt(mapper, input);

    PracticeGenerationCanonicalContract.Question question = result.paper().questions().get(0);
    assertEquals("SINGLE_CHOICE", question.type());
    assertEquals("A", question.options().get(0).key());
    assertEquals("B", question.options().get(1).key());
    assertEquals("C", question.options().get(2).key());
    assertEquals("B", question.answerSpec());
    assertTrue(result.coercedPaths().contains("$.questions[0].options[0]"));
    assertTrue(result.coercedPaths().contains("$.questions[0].answerSpec"));
  }

  @Test
  void adaptsMapAndLabelOnlyOptionShapes() throws Exception {
    String mapOptions = paperWithQuestion("""
        {
          "type": "SINGLE_CHOICE",
          "stem": "哪一个等于6？",
          "options": {"A": "5", "B": "6", "C": "7"},
          "answerSpec": "6",
          "explanation": "6就是6。",
          "hints": ["关键词：等于6"],
          "tags": ["数的认识"]
        }
        """);

    PracticeGenerationProviderAdapter.Result mapResult =
        PracticeGenerationProviderAdapter.adapt(mapper, mapOptions);
    PracticeGenerationCanonicalContract.Question mapQuestion =
        mapResult.paper().questions().get(0);
    assertEquals("B", mapQuestion.answerSpec());
    assertEquals("6", mapQuestion.options().get(1).label());

    String labelOnlyOptions = paperWithQuestion("""
        {
          "type": "SINGLE_CHOICE",
          "stem": "哪一个等于6？",
          "options": [
            {"label": "5"},
            {"label": "6"},
            {"label": "7"}
          ],
          "answerSpec": "6",
          "explanation": "6就是6。",
          "hints": ["关键词：等于6"],
          "tags": ["数的认识"]
        }
        """);

    PracticeGenerationProviderAdapter.Result labelOnlyResult =
        PracticeGenerationProviderAdapter.adapt(mapper, labelOnlyOptions);
    PracticeGenerationCanonicalContract.Question labelOnlyQuestion =
        labelOnlyResult.paper().questions().get(0);
    assertEquals("A", labelOnlyQuestion.options().get(0).key());
    assertEquals("B", labelOnlyQuestion.answerSpec());
  }

  @Test
  void unwrapsKnownScalarWrappersAcrossCanonicalFields() throws Exception {
    String input = """
        {
          "title": {"text": "退位减法练习"},
          "description": {"value": "专项练习"},
          "estimatedMinutes": {"minutes": "8"},
          "tags": [{"text": "退位减法"}],
          "questions": [
            {
              "type": {"value": "number"},
              "stem": {"text": "41 - 5 = ?"},
              "options": [],
              "answerSpec": {"answer": {"value": 36}},
              "explanation": {"content": "41减5等于36。"},
              "hints": [{"text": "关键词：41、减5"}],
              "tags": [{"name": "退位减法"}]
            }
          ]
        }
        """;

    PracticeGenerationProviderAdapter.Result result =
        PracticeGenerationProviderAdapter.adapt(mapper, input);

    assertEquals("退位减法练习", result.paper().title());
    assertEquals(8, result.paper().estimatedMinutes());
    PracticeGenerationCanonicalContract.Question question = result.paper().questions().get(0);
    assertEquals("NUMBER", question.type());
    assertEquals("36", question.answerSpec());
    assertEquals("关键词：41、减5", question.hints().get(0));
    assertTrue(result.coercedPaths().contains("$.questions[0].answerSpec"));
  }


  @Test
  void prefersUniqueLabelWhenGeneratedKeyCollidesWithProviderAnswerText() throws Exception {
    String input = paperWithQuestion("""
        {
          "type": "SINGLE_CHOICE",
          "stem": "请选择正确选项。",
          "options": ["B", "X", "Y"],
          "answerSpec": "B",
          "explanation": "选项文本 B 是正确答案。",
          "hints": ["关键词：正确选项"],
          "tags": ["测试"]
        }
        """);

    PracticeGenerationProviderAdapter.Result result =
        PracticeGenerationProviderAdapter.adapt(mapper, input);

    PracticeGenerationCanonicalContract.Question question = result.paper().questions().get(0);
    assertEquals("A", question.answerSpec());
    assertEquals("B", question.options().get(0).label());
    assertEquals("B", question.options().get(1).key());
  }

  @Test
  void keepsExplicitProviderKeyWhenLabelTextMatchesAnotherOptionKey() throws Exception {
    String input = paperWithQuestion("""
        {
          "type": "SINGLE_CHOICE",
          "stem": "请选择正确选项。",
          "options": [
            {"key": "A", "label": "B"},
            {"key": "B", "label": "X"},
            {"key": "C", "label": "Y"}
          ],
          "answerSpec": "B",
          "explanation": "Provider 明确返回 key B。",
          "hints": ["关键词：正确选项"],
          "tags": ["测试"]
        }
        """);

    PracticeGenerationProviderAdapter.Result result =
        PracticeGenerationProviderAdapter.adapt(mapper, input);

    assertEquals("B", result.paper().questions().get(0).answerSpec());
  }

  @Test
  void canonicalizesMissingOptionsAndScalarListsForNonChoiceQuestion() throws Exception {
    String input = """
        {
          "title": "退位减法练习",
          "description": "专项练习",
          "estimatedMinutes": 8,
          "tags": "退位减法",
          "questions": [
            {
              "type": "NUMBER",
              "stem": "41 - 5 = ?",
              "answerSpec": "36",
              "explanation": "41减5等于36。",
              "hints": "关键词：41、减5",
              "tags": {"text": "退位减法"}
            }
          ]
        }
        """;

    PracticeGenerationProviderAdapter.Result result =
        PracticeGenerationProviderAdapter.adapt(mapper, input);

    PracticeGenerationCanonicalContract.Question question = result.paper().questions().get(0);
    assertTrue(question.options().isEmpty());
    assertEquals(List.of("退位减法"), result.paper().tags());
    assertEquals(List.of("关键词：41、减5"), question.hints());
    assertEquals(List.of("退位减法"), question.tags());
    assertTrue(result.coercedPaths().contains("$.questions[0].options"));
    assertTrue(result.coercedPaths().contains("$.tags"));
    assertTrue(result.coercedPaths().contains("$.questions[0].hints"));
  }

  @Test
  void rejectsMissingOptionsForSingleChoiceQuestion() {
    String input = paperWithQuestion("""
        {
          "type": "SINGLE_CHOICE",
          "stem": "哪一个等于6？",
          "answerSpec": "B",
          "explanation": "6就是6。",
          "hints": ["关键词：等于6"],
          "tags": ["数的认识"]
        }
        """);

    IllegalArgumentException error = assertThrows(
        IllegalArgumentException.class,
        () -> PracticeGenerationProviderAdapter.adapt(mapper, input));

    assertTrue(error.getMessage().contains("$.questions[0].options is required for SINGLE_CHOICE"));
  }

  @Test
  void unwrapsUnknownAndNestedProviderEnvelopeByCanonicalShape() throws Exception {
    String canonical = paperWithQuestion("""
        {
          "type": "NUMBER",
          "stem": "8 + 7 = ?",
          "options": [],
          "answerSpec": "15",
          "explanation": "8加7等于15。",
          "hints": ["关键词：8、加7"],
          "tags": ["加法"]
        }
        """);

    String unknownWrapper = "{\"practicePayload\":" + canonical + "}";
    PracticeGenerationProviderAdapter.Result direct =
        PracticeGenerationProviderAdapter.adapt(mapper, unknownWrapper);
    assertEquals("测试练习", direct.paper().title());
    assertTrue(direct.coercedPaths().contains("$.practicePayload"));

    String nestedWrapper = "{\"vendorEnvelope\":{\"generatedContent\":" + canonical + "}}";
    PracticeGenerationProviderAdapter.Result nested =
        PracticeGenerationProviderAdapter.adapt(mapper, nestedWrapper);
    assertEquals("测试练习", nested.paper().title());
    assertTrue(nested.coercedPaths().contains("$.vendorEnvelope.generatedContent"));
  }

  @Test
  void rejectsAmbiguousGenericPaperEnvelope() {
    String canonical = paperWithQuestion("""
        {
          "type": "NUMBER",
          "stem": "8 + 7 = ?",
          "options": [],
          "answerSpec": "15",
          "explanation": "8加7等于15。",
          "hints": ["关键词：8、加7"],
          "tags": ["加法"]
        }
        """);
    String input = "{\"first\":" + canonical + ",\"second\":" + canonical + "}";

    IllegalArgumentException error = assertThrows(
        IllegalArgumentException.class,
        () -> PracticeGenerationProviderAdapter.adapt(mapper, input));

    assertTrue(error.getMessage().contains("multiple canonical paper candidates"));
  }

  @Test
  void rejectsConflictingScalarWrapperCandidates() {
    String input = paperWithQuestion("""
        {
          "type": "SINGLE_CHOICE",
          "stem": "哪一个等于6？",
          "options": [
            {"key": "A", "label": "5"},
            {"key": "B", "label": "6"},
            {"key": "C", "label": "7"}
          ],
          "answerSpec": {"value": "B", "answer": "A"},
          "explanation": "6就是6。",
          "hints": ["关键词：等于6"],
          "tags": ["数的认识"]
        }
        """);

    IllegalArgumentException error = assertThrows(
        IllegalArgumentException.class,
        () -> PracticeGenerationProviderAdapter.adapt(mapper, input));

    assertTrue(error.getMessage().contains("conflicting scalar wrapper values"));
  }

  @Test
  void rejectsAmbiguousAnswerLabelInsteadOfGuessing() {
    String input = paperWithQuestion("""
        {
          "type": "SINGLE_CHOICE",
          "stem": "选择正确答案。",
          "options": ["相同", "相同", "不同"],
          "answerSpec": "相同",
          "explanation": "测试歧义。",
          "hints": ["关键词：选择"],
          "tags": ["测试"]
        }
        """);

    IllegalArgumentException error = assertThrows(
        IllegalArgumentException.class,
        () -> PracticeGenerationProviderAdapter.adapt(mapper, input));

    assertTrue(error.getMessage().contains("matches multiple option labels"));
  }

  private static String paperWithQuestion(String question) {
    return """
        {
          "title": "测试练习",
          "description": "Provider Adapter 测试",
          "estimatedMinutes": 10,
          "tags": ["测试"],
          "questions": [
        """ + question + """
          ]
        }
        """;
  }
}
