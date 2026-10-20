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
}
