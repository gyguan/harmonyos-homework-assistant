package com.xiaoban.homework.ai;

import java.net.URI;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

@Component
public class OpenAiCompatibleTransport {
  private static final Logger log = LoggerFactory.getLogger(OpenAiCompatibleTransport.class);
  private static final Pattern ERROR_FIELD = Pattern.compile(
      "\\\"(message|type|code|param)\\\"\\s*:\\s*(\\\"((?:\\\\.|[^\\\"])*)\\\"|null|true|false|-?\\d+(?:\\.\\d+)?)",
      Pattern.CASE_INSENSITIVE);
  private static final int MAX_ERROR_LOG_CHARS = 500;

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

    log.info(
        "[AI] config protocol={} baseUrl={} responsesPath={} chatCompletionsPath={} tutorModel={} organizerModel={} structuredOutput={} keyConfigured={} allowUnauthenticated={}",
        properties.getProtocol(), safeBaseUrl(properties.getBaseUrl()), properties.getResponsesPath(),
        properties.getChatCompletionsPath(), properties.getTutorModel(), properties.getOrganizerModel(),
        properties.isStructuredOutput(), keyConfigured(), properties.isAllowUnauthenticated());
  }

  public boolean available(String model) {
    return properties.available(model);
  }

  public Optional<String> complete(String model, String instructions, String input, int maxTokens,
      String schemaName, Map<String, Object> schema) {
    String path = properties.usesChatCompletions()
        ? properties.getChatCompletionsPath()
        : properties.getResponsesPath();
    String protocol = properties.usesChatCompletions() ? "chat-completions" : "responses";

    if (!available(model)) {
      log.warn(
          "[AI] unavailable protocol={} baseUrl={} path={} model={} keyConfigured={} allowUnauthenticated={}",
          protocol, safeBaseUrl(properties.getBaseUrl()), path, model, keyConfigured(),
          properties.isAllowUnauthenticated());
      return Optional.empty();
    }

    long started = System.nanoTime();
    log.info("[AI] request protocol={} model={} path={} structuredOutput={} maxTokens={}",
        protocol, model, path, schema != null && properties.isStructuredOutput(), maxTokens);
    try {
      Optional<String> result = properties.usesChatCompletions()
          ? chatCompletion(model, instructions, input, maxTokens, schemaName, schema)
          : responses(model, instructions, input, maxTokens, schemaName, schema);
      long elapsedMs = elapsedMs(started);
      if (result.isPresent()) {
        log.info("[AI] response ok protocol={} model={} path={} elapsedMs={} outputChars={}",
            protocol, model, path, elapsedMs, result.get().length());
      } else {
        log.warn("[AI] response empty protocol={} model={} path={} elapsedMs={}",
            protocol, model, path, elapsedMs);
      }
      return result;
    } catch (RestClientResponseException error) {
      String providerError = redactExact(
          sanitizeProviderError(error.getResponseBodyAsString()), properties.getApiKey());
      log.warn(
          "[AI] response error protocol={} model={} path={} status={} elapsedMs={} exception={} providerError={}",
          protocol, model, path, error.getStatusCode().value(), elapsedMs(started),
          error.getClass().getSimpleName(), providerError);
      return Optional.empty();
    } catch (Exception error) {
      log.warn(
          "[AI] request failed protocol={} model={} path={} elapsedMs={} exception={} message={}",
          protocol, model, path, elapsedMs(started), error.getClass().getSimpleName(),
          safeMessage(error.getMessage()));
      return Optional.empty();
    }
  }

  private Optional<String> responses(String model, String instructions, String input, int maxTokens,
      String schemaName, Map<String, Object> schema) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("model", model);
    body.put("store", false);
    body.put("stream", false);
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
    body.put("stream", false);
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
    RestClient.RequestBodySpec request = client.post().uri(path).accept(MediaType.APPLICATION_JSON);
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

  static String sanitizeProviderError(String rawBody) {
    if (rawBody == null || rawBody.isBlank()) return "<empty>";
    String compact = rawBody.replace('\r', ' ').replace('\n', ' ').replace('\t', ' ').trim();

    Matcher matcher = ERROR_FIELD.matcher(compact);
    StringBuilder selected = new StringBuilder();
    while (matcher.find()) {
      if (selected.length() > 0) selected.append("; ");
      selected.append(matcher.group(1)).append('=').append(matcher.group(2));
      if (selected.length() >= MAX_ERROR_LOG_CHARS) break;
    }
    String safe = selected.length() > 0 ? selected.toString() : compact;
    safe = safe.replaceAll("(?i)Bearer\\s+[A-Za-z0-9._~+\\-/]+=*", "Bearer ***");
    safe = safe.replaceAll("(?i)sk-[A-Za-z0-9_-]{6,}", "sk-***");
    safe = safe.replaceAll("(?i)(api[-_]?key\\s*[=:]\\s*[\\\"']?)[^\\s,}\\\"']+", "$1***");
    return truncate(safe, MAX_ERROR_LOG_CHARS);
  }

  private boolean keyConfigured() {
    return properties.getApiKey() != null && !properties.getApiKey().isBlank();
  }

  private static long elapsedMs(long started) {
    return TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started);
  }

  private static String safeBaseUrl(String value) {
    if (value == null || value.isBlank()) return "<empty>";
    try {
      URI uri = URI.create(value.trim());
      StringBuilder safe = new StringBuilder();
      if (uri.getScheme() != null) safe.append(uri.getScheme()).append("://");
      if (uri.getHost() != null) safe.append(uri.getHost());
      else return "<invalid>";
      if (uri.getPort() >= 0) safe.append(':').append(uri.getPort());
      if (uri.getPath() != null && !uri.getPath().isBlank() && !"/".equals(uri.getPath())) {
        safe.append(uri.getPath());
      }
      return safe.toString();
    } catch (Exception ignored) {
      return "<invalid>";
    }
  }

  private static String safeMessage(String value) {
    return sanitizeProviderError(value == null ? "<empty>" : value);
  }

  private static String redactExact(String value, String secret) {
    if (value == null || secret == null || secret.isBlank()) return value;
    return value.replace(secret, "***");
  }

  private static String truncate(String value, int maxChars) {
    if (value == null) return "<empty>";
    if (value.length() <= maxChars) return value;
    return value.substring(0, maxChars) + "...";
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
