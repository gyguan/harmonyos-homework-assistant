package com.xiaoban.homework.ai;

import java.util.List;
import java.util.Map;
import tools.jackson.databind.json.JsonMapper;

/**
 * Normalizes transport/provider formatting around an otherwise structured JSON payload.
 * It intentionally does not rewrite business fields.
 */
public final class StructuredJsonNormalizer {
  private static final List<String> WRAPPER_KEYS = List.of(
      "paper", "data", "result", "output", "response");

  private StructuredJsonNormalizer() {}

  public record Result(String json, String shape) {}

  public static Result normalize(JsonMapper mapper, String raw) throws Exception {
    return normalize(mapper, raw, 0);
  }

  private static Result normalize(JsonMapper mapper, String raw, int depth) throws Exception {
    if (depth > 4) throw new IllegalArgumentException("structured JSON nesting is too deep");
    String text = raw == null ? "" : raw.trim();
    if (text.isBlank()) throw new IllegalArgumentException("structured JSON output is empty");

    String unfenced = stripFence(text);
    if (!unfenced.equals(text)) {
      Result nested = normalize(mapper, unfenced, depth + 1);
      return new Result(nested.json(), "fenced>" + nested.shape());
    }

    if (looksQuotedJson(text)) {
      String decoded = mapper.readValue(text, String.class);
      Result nested = normalize(mapper, decoded, depth + 1);
      return new Result(nested.json(), "quoted>" + nested.shape());
    }

    String extracted = extractFirstJsonValue(text);
    if (!extracted.equals(text)) {
      Result nested = normalize(mapper, extracted, depth + 1);
      return new Result(nested.json(), "embedded>" + nested.shape());
    }

    if (text.startsWith("[")) {
      List<?> values = mapper.readValue(text, List.class);
      if (values.size() != 1) {
        throw new IllegalArgumentException(
            "structured JSON root array must contain exactly one object");
      }
      Object only = values.get(0);
      if (!(only instanceof Map<?, ?>)) {
        throw new IllegalArgumentException(
            "structured JSON singleton array must contain an object");
      }
      return new Result(mapper.writeValueAsString(only), "singleton-array>object");
    }

    if (!text.startsWith("{")) {
      throw new IllegalArgumentException("structured JSON root must be an object");
    }

    Map<?, ?> root = mapper.readValue(text, Map.class);
    for (String key : WRAPPER_KEYS) {
      if (!root.containsKey(key)) continue;
      Object nestedValue = root.get(key);
      if (nestedValue instanceof Map<?, ?> nestedMap) {
        return new Result(mapper.writeValueAsString(nestedMap), "wrapper:" + key + ">object");
      }
      if (nestedValue instanceof String nestedText && looksLikeJson(nestedText)) {
        Result nested = normalize(mapper, nestedText, depth + 1);
        return new Result(nested.json(), "wrapper:" + key + ">" + nested.shape());
      }
    }
    return new Result(text, "object");
  }

  private static String stripFence(String value) {
    String text = value.trim();
    if (!text.startsWith("```")) return text;
    int firstLineEnd = text.indexOf('\n');
    int lastFence = text.lastIndexOf("```");
    if (firstLineEnd < 0 || lastFence <= firstLineEnd) return text;
    return text.substring(firstLineEnd + 1, lastFence).trim();
  }

  private static boolean looksQuotedJson(String value) {
    String text = value.trim();
    if (text.length() < 4 || text.charAt(0) != '"' || text.charAt(text.length() - 1) != '"') {
      return false;
    }
    return text.contains("\\{") || text.contains("\\[") || text.contains("{") || text.contains("[");
  }

  private static boolean looksLikeJson(String value) {
    if (value == null) return false;
    String text = value.trim();
    return text.startsWith("{") || text.startsWith("[") || looksQuotedJson(text)
        || text.startsWith("```");
  }

  private static String extractFirstJsonValue(String value) {
    String text = value.trim();
    int objectStart = text.indexOf('{');
    int arrayStart = text.indexOf('[');
    int start;
    if (objectStart < 0) start = arrayStart;
    else if (arrayStart < 0) start = objectStart;
    else start = Math.min(objectStart, arrayStart);
    if (start <= 0) return text;

    char open = text.charAt(start);
    char close = open == '{' ? '}' : ']';
    int depth = 0;
    boolean inString = false;
    boolean escaped = false;
    for (int i = start; i < text.length(); i++) {
      char current = text.charAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (current == '\\') {
          escaped = true;
        } else if (current == '"') {
          inString = false;
        }
        continue;
      }
      if (current == '"') {
        inString = true;
      } else if (current == open) {
        depth++;
      } else if (current == close) {
        depth--;
        if (depth == 0) return text.substring(start, i + 1).trim();
      }
    }
    return text;
  }
}
