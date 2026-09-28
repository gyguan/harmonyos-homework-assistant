package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeGenerationProviderAdapterTest {
  private final PracticeGenerationProviderAdapter adapter =
      new PracticeGenerationProviderAdapter(JsonMapper.builder().build());

  @Test
  void convertsStringOptionsAndAnswerLabelToCanonicalKeys() throws Exception {
    PracticeGenerationProviderAdapter.Result result = adapter.adapt("""
        {
          "title":"购物练习",
          "description":"认识人民币",
          "estimatedMinutes":8,
          "tags":["人民币"],
          "questions":[{
            "type":"choice",
            "stem":"一盒彩笔5元，正确价格是哪一个？",
            "options":["5元","6元","7元"],
            "answerSpec":"5元",
            "explanation":"题目中说明一盒彩笔5元。",
            "hints":["关键词：彩笔、5元"],
            "tags":["人民币"]
          }]
        }
        """);

    PracticeGenerationContract.Question question = result.paper().questions().get(0);
    assertEquals("SINGLE_CHOICE", question.type());
    assertEquals("A", question.options().get(0).key());
    assertEquals("5元", question.options().get(0).label());
    assertEquals("B", question.options().get(1).key());
    assertEquals("A", question.answerSpec());
    assertTrue(result.adaptations().contains("$.questions[0].options[0](scalar->option)"));
    assertTrue(result.adaptations().contains("$.questions[0].answerSpec(label->key)"));
  }

  @Test
  void convertsMapOptionsAndOriginalNumericAnswerKey() throws Exception {
    PracticeGenerationProviderAdapter.Result result = adapter.adapt("""
        {
          "title":"选择练习",
          "description":"基础练习",
          "estimatedMinutes":5,
          "tags":["基础"],
          "questions":[{
            "type":"SINGLE_CHOICE",
            "stem":"请选择正确答案。",
            "options":{"1":"5元","2":"6元","3":"7元"},
            "answerSpec":"2",
            "explanation":"正确答案是6元。",
            "hints":["关键词：正确答案"],
            "tags":["基础"]
          }]
        }
        """);

    PracticeGenerationContract.Question question = result.paper().questions().get(0);
    assertEquals("A", question.options().get(0).key());
    assertEquals("B", question.options().get(1).key());
    assertEquals("B", question.answerSpec());
    assertTrue(result.adaptations().contains("$.questions[0].options(map->options)"));
  }

  @Test
  void assignsCanonicalKeysWhenOptionObjectsOnlyContainLabels() throws Exception {
    PracticeGenerationProviderAdapter.Result result = adapter.adapt("""
        {
          "title":"选择练习",
          "description":"基础练习",
          "estimatedMinutes":5,
          "tags":["基础"],
          "questions":[{
            "type":"单选题",
            "stem":"请选择正确答案。",
            "options":[{"label":"甲"},{"label":"乙"},{"label":"丙"}],
            "answerSpec":"乙",
            "explanation":"乙是正确答案。",
            "hints":["关键词：选择"],
            "tags":["基础"]
          }]
        }
        """);

    PracticeGenerationContract.Question question = result.paper().questions().get(0);
    assertEquals("SINGLE_CHOICE", question.type());
    assertEquals("A", question.options().get(0).key());
    assertEquals("B", question.options().get(1).key());
    assertEquals("B", question.answerSpec());
    assertTrue(result.adaptations().contains("$.questions[0].options[0].key(auto)"));
  }
}
