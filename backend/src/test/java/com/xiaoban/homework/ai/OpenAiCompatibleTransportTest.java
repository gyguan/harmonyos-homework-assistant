package com.xiaoban.homework.ai;

import com.xiaoban.homework.ai.AiProviderCapabilities.StructuredOutputMode;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class OpenAiCompatibleTransportTest {
  @Test
  void extractsResponsesOutputText() {
    var response = new OpenAiCompatibleTransport.ResponsesResponse(List.of(
        new OpenAiCompatibleTransport.ResponsesOutput(List.of(
            new OpenAiCompatibleTransport.ResponsesContent("output_text", "先想想十位发生了什么。")))));
    assertEquals("先想想十位发生了什么。",
        OpenAiCompatibleTransport.extractResponsesText(response).orElseThrow());
  }

  @Test
  void buildsProviderIndependentStructuredOutputFormats() {
    Map<String, Object> schema = Map.of("type", "object");

    Map<String, Object> responsesSchema = OpenAiCompatibleTransport.structuredFormat(
        StructuredOutputMode.JSON_SCHEMA,
        "practice_generation",
        schema);
    assertEquals("json_schema", responsesSchema.get("type"));
    assertEquals(schema, responsesSchema.get("schema"));

    Map<String, Object> responsesJsonObject = OpenAiCompatibleTransport.structuredFormat(
        StructuredOutputMode.JSON_OBJECT,
        "practice_generation",
        schema);
    assertEquals(Map.of("type", "json_object"), responsesJsonObject);

    Map<String, Object> chatSchema = OpenAiCompatibleTransport.chatStructuredResponseFormat(
        StructuredOutputMode.JSON_SCHEMA,
        "practice_generation",
        schema);
    assertEquals("json_schema", chatSchema.get("type"));
    Map<?, ?> nested = (Map<?, ?>) chatSchema.get("json_schema");
    assertEquals(Boolean.TRUE, nested.get("strict"));
    assertEquals(schema, nested.get("schema"));

    Map<String, Object> chatJsonObject = OpenAiCompatibleTransport.chatStructuredResponseFormat(
        StructuredOutputMode.JSON_OBJECT,
        "practice_generation",
        schema);
    assertEquals(Map.of("type", "json_object"), chatJsonObject);

    assertNull(OpenAiCompatibleTransport.structuredFormat(
        StructuredOutputMode.TEXT,
        "practice_generation",
        schema));
    assertNull(OpenAiCompatibleTransport.chatStructuredResponseFormat(
        StructuredOutputMode.TEXT,
        "practice_generation",
        schema));
  }

  @Test
  void deserializesOpenAiCompatibleChatResponseWithProviderExtraFields() throws Exception {
    JsonMapper mapper = JsonMapper.builder().build();
    String raw = """
        {
          "id": "glm-response",
          "request_id": "req-1",
          "model": "glm-4.7",
          "choices": [
            {
              "index": 0,
              "message": {
                "role": "assistant",
                "reasoning_content": "内部推理字段",
                "content": "{\\\"questions\\\":[]}"
              },
              "finish_reason": "stop"
            }
          ],
          "usage": {
            "prompt_tokens": 12,
            "completion_tokens": 8
          }
        }
        """;

    OpenAiCompatibleTransport.ChatResponse response =
        mapper.readValue(raw, OpenAiCompatibleTransport.ChatResponse.class);

    assertEquals("{\"questions\":[]}",
        OpenAiCompatibleTransport.extractChatText(response).orElseThrow());
  }

  @Test
  void turnsOffModelThinkingForStructuredCallsOnly() throws Exception {
    // 思考过程对「照原文拆条」这类抽取任务没有帮助，实测同一张作业图 37.5s → 8.8s。
    assertEquals("disabled", bodyOf("glm-4.6v-flashx", Map.of("type", "object")).path("thinking").path("type").asText());
    // 对话式调用（tutor）不带 schema，保持厂商默认行为。
    assertNull(bodyOf("glm-4.6v-flashx", null).get("thinking"));
    // 非智谱厂商不认识 thinking 字段，不能带。
    assertNull(bodyOf("gpt-4o-mini", Map.of("type", "object")).get("thinking"));
  }

  private tools.jackson.databind.JsonNode bodyOf(String model, Map<String, Object> schema) throws Exception {
    var received = new java.util.concurrent.atomic.AtomicReference<String>();
    var server = com.sun.net.httpserver.HttpServer.create(new java.net.InetSocketAddress("127.0.0.1", 0), 0);
    server.createContext("/v1/chat/completions", exchange -> {
      received.set(new String(exchange.getRequestBody().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8));
      byte[] bytes = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"{}\"}}]}"
          .getBytes(java.nio.charset.StandardCharsets.UTF_8);
      exchange.getResponseHeaders().set("Content-Type", "application/json");
      exchange.sendResponseHeaders(200, bytes.length);
      exchange.getResponseBody().write(bytes);
      exchange.close();
    });
    server.start();
    try {
      var props = new AiProviderProperties();
      props.setBaseUrl("http://127.0.0.1:" + server.getAddress().getPort());
      props.setProtocol("chat-completions");
      props.setAllowUnauthenticated(true);
      var transport = new OpenAiCompatibleTransport(
          props, new AiProviderCapabilityResolver(props), JsonMapper.builder().build());
      transport.complete(model, "规则", "原文", 800, "homework", schema);
      return JsonMapper.builder().build().readTree(received.get());
    } finally {
      server.stop(0);
    }
  }

  @Test
  void extractsChatCompletionText() {
    var response = new OpenAiCompatibleTransport.ChatResponse(List.of(
        new OpenAiCompatibleTransport.ChatChoice(
            new OpenAiCompatibleTransport.ChatMessage("assistant", "先把题目中的已知条件圈出来。"))));
    assertEquals("先把题目中的已知条件圈出来。",
        OpenAiCompatibleTransport.extractChatText(response).orElseThrow());
  }
}
