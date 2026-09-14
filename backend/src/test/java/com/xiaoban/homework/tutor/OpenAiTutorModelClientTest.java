package com.xiaoban.homework.tutor;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class OpenAiTutorModelClientTest {
  @Test
  void extractsResponsesOutputText() throws Exception {
    JsonNode json = new ObjectMapper().readTree("{\"output\":[{\"content\":[{\"type\":\"output_text\",\"text\":\"先想想十位发生了什么。\"}]}]}");
    assertEquals("先想想十位发生了什么。", OpenAiTutorModelClient.extractText(json).orElseThrow());
  }
}
