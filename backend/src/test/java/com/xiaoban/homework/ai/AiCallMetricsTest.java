package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class AiCallMetricsTest {
  private final JsonMapper json = JsonMapper.builder().build();
  @Test void readsBothProtocolsWithoutEstimatingMissingUsage() {
    var chat = AiCallMetrics.usage(json.readTree("""
        {"usage":{"prompt_tokens":12,"completion_tokens":7,"prompt_tokens_details":{"cached_tokens":4}}}
        """));
    assertEquals(12L, chat.tokensIn()); assertEquals(7L, chat.tokensOut()); assertEquals(4L, chat.cachedTokens());
    var responses = AiCallMetrics.usage(json.readTree("{\"usage\":{\"input_tokens\":0,\"output_tokens\":8}}"));
    assertEquals(0L, responses.tokensIn()); assertEquals(8L, responses.tokensOut());
    assertNull(AiCallMetrics.usage(json.readTree("{}")).tokensIn());
    assertNull(AiCallMetrics.usage(json.readTree("{\"usage\":{\"prompt_tokens\":-1}}")).tokensIn());
  }
  @Test void requestScopesCannotLeakAcrossThreadsOrSubsequentRequests() throws Exception {
    try (var first = AiCallMetrics.open()) {
      AiCallMetrics.record(new AiCallMetrics.Call("PRIMARY", "mock", 5, false, new AiCallMetrics.Usage(null, null, null)));
      var thread = new Thread(() -> assertFalse(AiCallMetrics.active()));
      thread.start(); thread.join();
      assertEquals(1, first.calls().size());
      try (var nested = AiCallMetrics.open()) { assertTrue(nested.calls().isEmpty()); }
      assertEquals(1, first.calls().size());
    }
    assertFalse(AiCallMetrics.active());
    try (var second = AiCallMetrics.open()) { assertTrue(second.calls().isEmpty()); }
  }
  @Test void readsActualImageAndCacheUsageOnlyWhenProviderSuppliesValidCounters() {
    var json = tools.jackson.databind.json.JsonMapper.builder().build();
    var chat=AiCallMetrics.usage(json.readTree("{\"usage\":{\"prompt_tokens\":100,\"completion_tokens\":20,\"prompt_tokens_details\":{\"cached_tokens\":30,\"image_tokens\":40}}}"));
    assertEquals(30L,chat.cachedTokens()); assertEquals(40L,chat.imageTokens());
    var responses=AiCallMetrics.usage(json.readTree("{\"usage\":{\"input_tokens_details\":{\"image_tokens\":15}}}"));
    assertEquals(15L,responses.imageTokens()); assertNull(responses.cachedTokens());
    for(String value:java.util.List.of("-1","1.5","true","\"12\"","null"))
      assertNull(AiCallMetrics.usage(json.readTree("{\"usage\":{\"input_tokens_details\":{\"image_tokens\":"+value+"}}}")).imageTokens());
  }

}
