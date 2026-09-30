package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.*;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.core.read.ListAppender;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;
import tools.jackson.databind.json.JsonMapper;

class ImageTransportTest {
  @Test
  void sendsActualImageContentWithBothProtocolsAndSuppressesPayloadLogs() throws Exception {
    for (String protocol : new String[] {"responses", "chat-completions"}) {
      var received = new AtomicReference<String>();
      var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
      String path = protocol.equals("responses") ? "/v1/responses" : "/v1/chat/completions";
      server.createContext(path, exchange -> {
        received.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
        String response = protocol.equals("responses")
            ? "{\"output\":[{\"content\":[{\"type\":\"output_text\",\"text\":\"parsed\"}]}]}"
            : "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"parsed\"}}]}";
        byte[] bytes = response.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(200, bytes.length);
        exchange.getResponseBody().write(bytes);
        exchange.close();
      });
      server.start();
      var appender = new ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>();
      appender.start();
      var logger = (Logger) LoggerFactory.getLogger(OpenAiCompatibleTransport.class);
      logger.addAppender(appender);
      try {
        var props = new AiProviderProperties();
        props.setBaseUrl("http://127.0.0.1:" + server.getAddress().getPort());
        props.setProvider("GENERIC");
        props.setProtocol(protocol);
        props.setAllowUnauthenticated(true);
        props.setLogPayloads(true);
        var mapper = JsonMapper.builder().build();
        var transport = new OpenAiCompatibleTransport(props, new AiProviderCapabilityResolver(props), mapper);
        String dataUrl = "data:image/jpeg;base64,PRIVATE_IMAGE_SENTINEL";
        assertEquals("parsed", transport.completeWithImage("vision-model", "JSON instructions",
            "student context", dataUrl, 6000, "homework", Map.of("type", "object")).orElseThrow());
        var body = mapper.readTree(received.get());
        assertEquals("vision-model", body.path("model").asText());
        if (protocol.equals("responses")) {
          var content = body.path("input").get(0).path("content");
          assertEquals("input_text", content.get(0).path("type").asText());
          assertEquals("student context", content.get(0).path("text").asText());
          assertEquals("input_image", content.get(1).path("type").asText());
          assertEquals(dataUrl, content.get(1).path("image_url").asText());
          assertFalse(body.path("store").asBoolean());
        } else {
          var content = body.path("messages").get(1).path("content");
          assertEquals("text", content.get(0).path("type").asText());
          assertEquals("image_url", content.get(1).path("type").asText());
          assertEquals(dataUrl, content.get(1).path("image_url").path("url").asText());
        }
        assertTrue(appender.list.stream().noneMatch(event ->
            event.getFormattedMessage().contains("PRIVATE_IMAGE_SENTINEL")
                || event.getFormattedMessage().contains("[AI-PAYLOAD]")));
      } finally {
        logger.detachAppender(appender);
        server.stop(0);
      }
    }
  }

  @Test
  void reportsImageHttpFailuresWithoutEchoingProviderContentOrRetrying() throws Exception {
    for (String protocol : new String[] {"responses", "chat-completions"}) {
      for (int status : new int[] {406, 401, 403, 429, 413, 503, 400}) {
        var calls = new AtomicInteger();
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        String path = protocol.equals("responses") ? "/v1/responses" : "/v1/chat/completions";
        server.createContext(path, exchange -> {
          calls.incrementAndGet();
          exchange.getRequestBody().readAllBytes();
          String body = "{\"error\":{\"code\":\"PRIVATE_CODE\",\"message\":\"PRIVATE_IMAGE PRIVATE_KEY PRIVATE_HOMEWORK\"}}";
          byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
          exchange.getResponseHeaders().set("Content-Type", "application/json; secret=PRIVATE_HEADER");
          exchange.sendResponseHeaders(status, bytes.length);
          exchange.getResponseBody().write(bytes);
          exchange.close();
        });
        server.start();
        var appender = new ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>();
        appender.start();
        var logger = (Logger) LoggerFactory.getLogger(OpenAiCompatibleTransport.class);
        logger.addAppender(appender);
        try {
          var props = new AiProviderProperties();
          props.setBaseUrl("http://127.0.0.1:" + server.getAddress().getPort());
          props.setProtocol(protocol);
          props.setApiKey("PRIVATE_KEY");
          props.setLogPayloads(true);
          var transport = new OpenAiCompatibleTransport(props, new AiProviderCapabilityResolver(props),
              JsonMapper.builder().build());
          var failure = assertThrows(ImageAiRequestException.class, () -> transport.completeWithImage(
              "deepseek-v4-flash-0731", "PRIVATE_HOMEWORK", "context",
              "data:image/jpeg;base64,PRIVATE_IMAGE", 6000, "homework", Map.of()));
          assertEquals(status, failure.status());
          var expectedReason = switch (status) {
            case 406 -> ImageAiRequestException.Reason.REQUEST_REJECTED;
            case 401, 403 -> ImageAiRequestException.Reason.AUTHENTICATION;
            case 429 -> ImageAiRequestException.Reason.RATE_LIMIT;
            case 413 -> ImageAiRequestException.Reason.REQUEST_TOO_LARGE;
            case 503 -> ImageAiRequestException.Reason.UPSTREAM_UNAVAILABLE;
            default -> ImageAiRequestException.Reason.HTTP_ERROR;
          };
          assertEquals(expectedReason, failure.reason());
          assertTrue(failure.getMessage().contains("HTTP " + status));
          assertNull(failure.getCause());
          assertEquals(1, calls.get());
          String logs = appender.list.stream().map(event -> event.getFormattedMessage())
              .collect(java.util.stream.Collectors.joining("\n"));
          assertTrue(logs.contains("reason=" + expectedReason));
          assertTrue(logs.contains("responseType=JSON"));
          assertFalse(logs.contains("PRIVATE_"));
          assertFalse(failure.getMessage().contains("PRIVATE_"));
          assertFalse(logs.contains("[AI-PAYLOAD]"));
          assertTrue(transport.complete("deepseek-v4-flash-0731", "instructions", "text",
              100, "homework", Map.of()).isEmpty());
          // Text-only callers retain their existing Optional.empty() failure contract.
          assertEquals(2, calls.get());
        } finally {
          logger.detachAppender(appender);
          server.stop(0);
        }
      }
    }
  }

  @Test
  void classifiesOnlyKnownCodesAndFallsBackSafelyForGatewayResponses() {
    var props = new AiProviderProperties();
    var transport = new OpenAiCompatibleTransport(props, new AiProviderCapabilityResolver(props),
        JsonMapper.builder().build());
    assertEquals(ImageAiRequestException.Reason.IMAGE_UNSUPPORTED,
        transport.imageFailureReason(400, "{\"error\":{\"code\":\"unsupported_image\"}}"));
    assertEquals(ImageAiRequestException.Reason.IMAGE_INVALID,
        transport.imageFailureReason(400, "{\"error\":{\"code\":\"invalid_image\"}}"));
    assertEquals(ImageAiRequestException.Reason.MODEL_NOT_FOUND,
        transport.imageFailureReason(404, "{\"error\":{\"code\":\"model_not_found\"}}"));
    assertEquals(ImageAiRequestException.Reason.REQUEST_REJECTED,
        transport.imageFailureReason(406, "<html>PRIVATE</html>"));
    assertEquals(ImageAiRequestException.Reason.REQUEST_REJECTED,
        transport.imageFailureReason(406, "PRIVATE".repeat(3000)));
    assertEquals(ImageAiRequestException.Reason.REQUEST_REJECTED,
        transport.imageFailureReason(406, null));
    assertEquals(ImageAiRequestException.Reason.AUTHENTICATION,
        transport.imageFailureReason(401, "{\"error\":{\"code\":\"unsupported_image\"}}"));
  }

  @Test
  void preservesTextOnlyRequestShape() {
    assertEquals("text", OpenAiCompatibleTransport.responsesInput("text", null));
    assertEquals("text", OpenAiCompatibleTransport.chatInput("text", null));
  }
}
