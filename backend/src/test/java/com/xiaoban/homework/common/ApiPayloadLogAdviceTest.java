package com.xiaoban.homework.common;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertSame;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.core.read.ListAppender;
import com.xiaoban.homework.organizer.HomeworkOrganizerDtos;
import java.util.List;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import tools.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.Test;

class ApiPayloadLogAdviceTest {
  @Test
  void imageBodiesAreNeverLoggedEvenWhenPayloadDiagnosticsAreEnabled() {
    var properties = new HttpLogProperties();
    properties.setLogPayloads(true);
    var advice = new ApiPayloadLogAdvice(properties, JsonMapper.builder().build());
    var appender = new ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>();
    appender.start();
    var logger = (Logger) LoggerFactory.getLogger(ApiPayloadLogAdvice.class);
    logger.addAppender(appender);
    try {
      var request = new HomeworkOrganizerDtos.ImageRequest("PRIVATE_IMAGE", "image/jpeg", "source", "PRIVATE_SUPPLEMENT_TEXT");
      assertSame(request, advice.afterBodyRead(request, null, null, null, null));
      var response = new HomeworkOrganizerDtos.ImageResponse(List.of(), "AI_IMAGE", "PRIVATE_RECOGNIZED_TEXT");
      assertSame(response, advice.beforeBodyWrite(response, null, MediaType.APPLICATION_JSON, null, null, null));
      assertTrue(appender.list.isEmpty());
    } finally {
      logger.detachAppender(appender);
    }
  }
  @Test
  void payloadLoggingIsDisabledByDefaultWithBoundedSize() {
    HttpLogProperties properties = new HttpLogProperties();
    assertFalse(properties.isLogPayloads());
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
