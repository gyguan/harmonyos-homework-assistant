package com.xiaoban.homework.ai;

import com.xiaoban.homework.ai.AiProviderCapabilities.StructuredOutputMode;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

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
  void extractsChatCompletionText() {
    var response = new OpenAiCompatibleTransport.ChatResponse(List.of(
        new OpenAiCompatibleTransport.ChatChoice(
            new OpenAiCompatibleTransport.ChatMessage("assistant", "先把题目中的已知条件圈出来。"))));
    assertEquals("先把题目中的已知条件圈出来。",
        OpenAiCompatibleTransport.extractChatText(response).orElseThrow());
  }
}
