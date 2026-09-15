package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class AiProviderLoggingTest {
  @Test
  void sanitizesProviderErrorBody() {
    String raw = "{\"error\":{\"message\":\"bad key sk-secret-1234567890\"},\"token\":\"Bearer abcdefghijklmnop\"}";
    String sanitized = OpenAiCompatibleTransport.sanitizeProviderError(raw);

    assertTrue(sanitized.contains("bad key"));
    assertFalse(sanitized.contains("sk-secret-1234567890"));
    assertFalse(sanitized.contains("abcdefghijklmnop"));
  }

  @Test
  void truncatesVeryLongProviderErrorBody() {
    String sanitized = OpenAiCompatibleTransport.sanitizeProviderError("x".repeat(1200));
    assertTrue(sanitized.length() <= 520);
    assertTrue(sanitized.endsWith("..."));
  }
}
