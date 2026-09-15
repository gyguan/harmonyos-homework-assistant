package com.xiaoban.homework.ai;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class OpenAiCompatibleTransport {
  private static final Logger log = LoggerFactory.getLogger(OpenAiCompatibleTransport.class);
  private final AiProviderProperties properties;
  private final RestClient client;

  public record ResponsesContent(String type, String text) {}
  public record ResponsesOutput(List<ResponsesContent> content) {}
  public record ResponsesResponse(List<ResponsesOutput> output) {}
  public record ChatMessage(String role, String content) {}
  public record ChatChoice(ChatMessage message) {}
  public record ChatResponse(List<ChatChoice> choices) {}

  public OpenAiCompatibleTransport(AiProviderProperties properties) {
    this.properties = properties;
    this.client = RestClient.builder()
        .baseUrl(properties.getBaseUrl())
        .defaultHeader(HttpHeaders.CONTENT_TYPE, "application/json")
        .build();
  }

  public boolean available(String model) {
    return properties.available(model);
  }

  public Optional<String> complete(String model, String instructions, String input, int maxTokens,
      String schemaName, Map<String, Object> schema) {
    if (!available(model)) return Optional.empty();
    try {
      return properties.usesChatCompletions()
          ? chatCompletion(model, instructions, input, maxTokens, schemaName, schema)
          : responses(model, instructions, input, maxTokens, schemaName, schema);
    } catch (Exception error) {
      log.warn("AI provider request failed: {}", error.getMessage());
      return Optional.empty();
    }
  }

  private Optional<String> responses(String model, String instructions, String input, int maxTokens,
      String schemaName, Map<String, Object> schema) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("model", model);
    body.put("store", false);
    body.put("instructions", instructions);
    body.put("input", input);
    body.put("max_output_tokens", maxTokens);
    if (schema != null && properties.isStructuredOutput()) {
      body.put("text", Map.of("format", jsonSchemaFormat(schemaName, schema)));
    }
    ResponsesResponse response = post(properties.getResponsesPath(), body, ResponsesResponse.class);
    return extractResponsesText(response);
  }

  private Optional<String> chatCompletion(String model, String instructions, String input, int maxTokens,
      String schemaName, Map<String, Object> schema) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("model", model);
    body.put("messages", List.of(
        Map.of("role", "system", "content", instructions),
        Map.of("role", "user", "content", input)));
    body.put("max_tokens", maxTokens);
    if (schema != null && properties.isStructuredOutput()) {
      body.put("response_format", Map.of(
          "type", "json_schema",
          "json_schema", Map.of(
              "name", safeSchemaName(schemaName),
              "strict", true,
              "schema", schema)));
    }
    ChatResponse response = post(properties.getChatCompletionsPath(), body, ChatResponse.class);
    return extractChatText(response);
  }

  private <T> T post(String path, Map<String, Object> body, Class<T> responseType) {
    RestClient.RequestBodySpec request = client.post().uri(path);
    if (properties.getApiKey() != null && !properties.getApiKey().isBlank()) {
      request.header(HttpHeaders.AUTHORIZATION, "Bearer " + properties.getApiKey());
    }
    return request.body(body).retrieve().body(responseType);
  }

  static Optional<String> extractResponsesText(ResponsesResponse response) {
    if (response == null || response.output() == null) return Optional.empty();
    for (ResponsesOutput item : response.output()) {
      if (item == null || item.content() == null) continue;
      for (ResponsesContent content : item.content()) {
        if (content != null && "output_text".equals(content.type()) && content.text() != null) {
          String text = content.text().trim();
          if (!text.isEmpty()) return Optional.of(text);
        }
      }
    }
    return Optional.empty();
  }

  static Optional<String> extractChatText(ChatResponse response) {
    if (response == null || response.choices() == null) return Optional.empty();
    for (ChatChoice choice : response.choices()) {
      if (choice == null || choice.message() == null || choice.message().content() == null) continue;
      String text = choice.message().content().trim();
      if (!text.isEmpty()) return Optional.of(text);
    }
    return Optional.empty();
  }

  private static Map<String, Object> jsonSchemaFormat(String schemaName, Map<String, Object> schema) {
    Map<String, Object> format = new LinkedHashMap<>();
    format.put("type", "json_schema");
    format.put("name", safeSchemaName(schemaName));
    format.put("strict", true);
    format.put("schema", schema);
    return format;
  }

  private static String safeSchemaName(String schemaName) {
    return schemaName == null || schemaName.isBlank() ? "structured_output" : schemaName;
  }
}
