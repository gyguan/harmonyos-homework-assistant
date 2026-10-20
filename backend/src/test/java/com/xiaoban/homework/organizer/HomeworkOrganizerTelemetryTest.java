package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import com.xiaoban.homework.ai.AiCallMetrics;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;

class HomeworkOrganizerTelemetryTest {
  @Test void failureAndPartialUsageRemainObservableWithoutPrivateContent() {
    MDC.put("requestId", "req-test");
    try (var trace = HomeworkOrganizerTelemetry.open("private text\nchild", "TEXT")) {
      HomeworkOrganizerTelemetry.versions("mock-model", "CUSTOM", "private prompt", "rules", "private experience");
      AiCallMetrics.record(new AiCallMetrics.Call("PRIMARY", "mock-model", 40, true, new AiCallMetrics.Usage(12L, 8L, null)));
      AiCallMetrics.record(new AiCallMetrics.Call("REVIEW", "mock-model", 20, false, new AiCallMetrics.Usage(null, null, null)));
      HomeworkOrganizerTelemetry.review("LEGACY_EXPERIENCE_MATCH");
      var data = trace.measurement();
      assertEquals(false, data.get("success")); assertEquals(2, data.get("callCount"));
      assertEquals("unavailable", data.get("tokensIn"));
      assertEquals("req-test", data.get("requestId"));
      assertFalse(data.toString().contains("private"));
    } finally { MDC.clear(); }
    assertFalse(AiCallMetrics.active());
  }
  @Test void recordsResolvedProviderRatherThanConfiguredAuto() {
    try (var trace = HomeworkOrganizerTelemetry.open("batch", "TEXT")) {
      HomeworkOrganizerTelemetry.versions("mock", "AUTO", "p", "r", "e");
      AiCallMetrics.record(new AiCallMetrics.Call("PRIMARY", "mock", 12, true,
          new AiCallMetrics.Usage(1L, 2L, 0L), "GENERIC_OPENAI_COMPATIBLE"));
      assertEquals("GENERIC_OPENAI_COMPATIBLE", trace.measurement().get("provider"));
      assertEquals(1L, trace.measurement().get("tokensIn"));
    }
  }

  @Test void imageAndCacheCountersAreActualAndPartialDetailsStayUnavailable() {
    try(var trace=HomeworkOrganizerTelemetry.open("image-usage","IMAGE")) {
      AiCallMetrics.record(new AiCallMetrics.Call("PRIMARY","mock",1,true,new AiCallMetrics.Usage(100L,20L,30L,40L)));
      AiCallMetrics.record(new AiCallMetrics.Call("REVIEW","mock",1,true,new AiCallMetrics.Usage(50L,10L,0L,15L)));
      assertEquals(55L,trace.measurement().get("imageTokensIn")); assertEquals(30L,trace.measurement().get("cachedTokensIn"));
      AiCallMetrics.record(new AiCallMetrics.Call("REVIEW","mock",1,true,new AiCallMetrics.Usage(1L,1L,null)));
      assertEquals("unavailable",trace.measurement().get("imageTokensIn"));
    }
  }

}
