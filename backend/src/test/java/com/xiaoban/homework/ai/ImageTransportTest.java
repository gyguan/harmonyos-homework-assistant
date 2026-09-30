package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.*;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.core.read.ListAppender;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
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
  void preservesTextOnlyRequestShape() {
    assertEquals("text", OpenAiCompatibleTransport.responsesInput("text", null));
    assertEquals("text", OpenAiCompatibleTransport.chatInput("text", null));
  }
}
