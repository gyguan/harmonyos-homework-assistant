package com.xiaoban.homework.common;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import tools.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.Test;

class ApiPayloadLogAdviceTest {
  @Test
  void payloadLoggingIsEnabledByDefaultWithBoundedSize() {
    HttpLogProperties properties = new HttpLogProperties();
    assertTrue(properties.isLogPayloads());
    assertTrue(properties.getMaxPayloadChars() >= 1000);
  }

  @Test
  void credentialFieldsAreRedactedWithoutHidingBusinessPayload() {
    HttpLogProperties properties = new HttpLogProperties();
    ApiPayloadLogAdvice advice = new ApiPayloadLogAdvice(properties, JsonMapper.builder().build());

    String sanitized = advice.sanitizeAndTruncate(
        "{\"studentId\":\"s1\",\"text\":\"数学第12页\",\"password\":\"parent123\",\"token\":\"abc123\"}");

    assertTrue(sanitized.contains("\"studentId\":\"s1\""));
    assertTrue(sanitized.contains("\"text\":\"数学第12页\""));
    assertTrue(sanitized.contains("\"password\":\"***\""));
    assertTrue(sanitized.contains("\"token\":\"***\""));
    assertFalse(sanitized.contains("parent123"));
    assertFalse(sanitized.contains("abc123"));
  }

  @Test
  void payloadIsTruncatedAtConfiguredLimit() {
    HttpLogProperties properties = new HttpLogProperties();
    properties.setMaxPayloadChars(1000);
    ApiPayloadLogAdvice advice = new ApiPayloadLogAdvice(properties, JsonMapper.builder().build());

    String sanitized = advice.sanitizeAndTruncate("x".repeat(1500));

    assertTrue(sanitized.length() <= 1003);
    assertTrue(sanitized.endsWith("..."));
  }
}
