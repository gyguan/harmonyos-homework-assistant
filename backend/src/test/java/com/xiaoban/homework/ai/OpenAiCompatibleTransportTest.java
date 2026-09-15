package com.xiaoban.homework.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;
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
  void extractsChatCompletionText() {
    var response = new OpenAiCompatibleTransport.ChatResponse(List.of(
        new OpenAiCompatibleTransport.ChatChoice(
            new OpenAiCompatibleTransport.ChatMessage("assistant", "先把题目中的已知条件圈出来。"))));
    assertEquals("先把题目中的已知条件圈出来。",
        OpenAiCompatibleTransport.extractChatText(response).orElseThrow());
  }
}
