package com.xiaoban.homework.common;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertSame;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.core.read.ListAppender;
import com.xiaoban.homework.organizer.HomeworkOrganizerDtos;
import com.xiaoban.homework.assignment.AssignmentDtos;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.http.server.ServletServerHttpRequest;
import org.springframework.http.server.ServletServerHttpResponse;
import java.util.Map;
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
  void publishedTaskRoutesNeverLogBodiesEvenInDiagnosticMode() {
    var properties = new HttpLogProperties();
    properties.setLogPayloads(true);
    var advice = new ApiPayloadLogAdvice(properties, JsonMapper.builder().build());
    var appender = new ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>();
    appender.start();
    var logger = (Logger) LoggerFactory.getLogger(ApiPayloadLogAdvice.class);
    logger.addAppender(appender);
    try {
      for (String uri : List.of("/api/v1/students/s1/assignments", "/api/v1/students/s1/assignments/batch",
          "/api/v1/students/s1/assignments/sync", "/api/v1/students/s1/assignments/page",
          "/api/v1/assignments/a-published-ai-batch-1", "/api/v1/assignments/a-published-ai-batch-1/details",
          "/api/v1/students/s1/homework/source-evidence/batch-1")) {
        var request = new ServletServerHttpRequest(new MockHttpServletRequest("GET", uri));
        var response = new ServletServerHttpResponse(new MockHttpServletResponse());
        var body = Map.of("title", "PRIVATE_TASK", "sourceExcerpt", "PRIVATE_TEACHER_SOURCE");
        assertSame(body, advice.afterBodyRead(body, request, null, null, null));
        // Collection wrappers also need path protection; checking only DTO instance types misses them.
        var rows = List.of(body);
        assertSame(rows, advice.beforeBodyWrite(rows, null, MediaType.APPLICATION_JSON, null, request, response));
      }
      assertTrue(appender.list.isEmpty());
      // Other diagnostics still use the existing sanitization path.
      var request = new ServletServerHttpRequest(new MockHttpServletRequest("POST", "/api/v1/auth/login"));
      advice.afterBodyRead(Map.of("password", "PRIVATE_PASSWORD"), request, null, null, null);
      assertFalse(appender.list.isEmpty());
      assertFalse(appender.list.getFirst().getFormattedMessage().contains("PRIVATE_PASSWORD"));
    } finally { logger.detachAppender(appender); }
  }

  @Test
  void assignmentDtoIsProtectedWithoutServletRequest() {
    var properties = new HttpLogProperties();
    properties.setLogPayloads(true);
    var advice = new ApiPayloadLogAdvice(properties, JsonMapper.builder().build());
    var appender = new ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>();
    appender.start();
    var logger = (Logger) LoggerFactory.getLogger(ApiPayloadLogAdvice.class);
    logger.addAppender(appender);
    try {
      var body = new AssignmentDtos.DetailsUpdate(1L, "PRIVATE_TITLE", "PRIVATE_INSTRUCTION", "P13", "2026-10-19", 10);
      assertSame(body, advice.afterBodyRead(body, null, null, null, null));
      var response = new AssignmentDtos.BatchPublishResponse(true, 0, List.of());
      assertSame(response, advice.beforeBodyWrite(response, null, MediaType.APPLICATION_JSON, null, null, null));
      assertTrue(appender.list.isEmpty());
    } finally { logger.detachAppender(appender); }
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
