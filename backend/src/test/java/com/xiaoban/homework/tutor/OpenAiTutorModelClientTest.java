package com.xiaoban.homework.tutor;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;
import org.junit.jupiter.api.Test;

class OpenAiTutorModelClientTest {
  @Test
  void extractsResponsesOutputText() {
    OpenAiTutorModelClient.OpenAiResponse response = new OpenAiTutorModelClient.OpenAiResponse(
        List.of(new OpenAiTutorModelClient.OpenAiOutput(
            List.of(new OpenAiTutorModelClient.OpenAiContent("output_text", "先想想十位发生了什么。")))));
    assertEquals("先想想十位发生了什么。", OpenAiTutorModelClient.extractText(response).orElseThrow());
  }
}
