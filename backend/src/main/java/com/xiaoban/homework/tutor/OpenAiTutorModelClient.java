package com.xiaoban.homework.tutor;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class OpenAiTutorModelClient implements TutorModelClient {
  private static final Logger log = LoggerFactory.getLogger(OpenAiTutorModelClient.class);
  private final String apiKey;
  private final String model;
  private final RestClient client;

  public OpenAiTutorModelClient(@Value("${app.tutor.openai.api-key:}") String apiKey,
      @Value("${app.tutor.openai.model:gpt-5.6-luna}") String model,
      @Value("${app.tutor.openai.base-url:https://api.openai.com}") String baseUrl) {
    this.apiKey = apiKey == null ? "" : apiKey.trim();
    this.model = model;
    this.client = RestClient.builder().baseUrl(baseUrl)
        .defaultHeader(HttpHeaders.CONTENT_TYPE, "application/json").build();
  }

  @Override
  public boolean available() { return !apiKey.isBlank(); }

  @Override
  public Optional<String> answer(TutorModelRequest request) {
    if (!available()) return Optional.empty();
    try {
      Map<String, Object> body = new LinkedHashMap<>();
      body.put("model", model);
      body.put("store", false);
      body.put("instructions", request.instructions());
      body.put("input", request.input());
      body.put("max_output_tokens", 700);
      JsonNode response = client.post().uri("/v1/responses")
          .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
          .body(body).retrieve().body(JsonNode.class);
      return extractText(response);
    } catch (Exception error) {
      log.warn("Tutor model request failed: {}", error.getMessage());
      return Optional.empty();
    }
  }

  static Optional<String> extractText(JsonNode response) {
    if (response == null) return Optional.empty();
    for (JsonNode item : response.path("output")) {
      for (JsonNode content : item.path("content")) {
        if ("output_text".equals(content.path("type").asText())) {
          String text = content.path("text").asText("").trim();
          if (!text.isEmpty()) return Optional.of(text);
        }
      }
    }
    return Optional.empty();
  }
}
