package com.xiaoban.homework.organizer;

import com.xiaoban.homework.ai.StructuredJsonNormalizer;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import tools.jackson.databind.json.JsonMapper;

/**
 * Adapts bounded provider variations for the second-stage duplicate review response.
 */
final class DuplicateReviewProviderAdapter {
  private DuplicateReviewProviderAdapter() {}

  record Result(
      ConfigurableHomeworkOrganizerModelClient.DuplicateReviewResult review,
      String shape,
      List<String> coercedPaths) {}

  static Result adapt(JsonMapper mapper, String raw) throws Exception {
    StructuredJsonNormalizer.Result normalized = StructuredJsonNormalizer.normalize(mapper, raw);
    Object parsed = mapper.readValue(normalized.json(), Object.class);
    Map<String, Object> root = objectMap(parsed, "$");
    Tracker tracker = new Tracker();

    Object matchesValue = pick(root, "$.matches", "matches", "duplicates", "duplicateMatches");
    List<?> source = matchList(mapper, matchesValue, "$.matches", tracker);
    List<ConfigurableHomeworkOrganizerModelClient.DuplicateDecision> matches = new ArrayList<>();

    for (int i = 0; i < source.size(); i++) {
      String base = "$.matches[" + i + "]";
      Map<String, Object> item = objectMap(source.get(i), base);

      int candidateIndex = candidateIndex(
          pick(item, base + ".candidateIndex", "candidateIndex", "candidate_index", "candidate"),
          base + ".candidateIndex", tracker);
      String assignmentId = stringValue(
          pick(item, base + ".duplicateAssignmentId",
              "duplicateAssignmentId", "duplicate_assignment_id", "assignmentId", "assignment_id"),
          base + ".duplicateAssignmentId", tracker);
      double confidence = confidenceValue(
          pick(item, base + ".confidence", "confidence", "duplicateConfidence", "score"),
          base + ".confidence", tracker);

      Object reasonRaw = pickOptional(item, "reason", "duplicateReason", "explanation");
      String reason;
      if (reasonRaw == null) {
        tracker.add(base + ".reason");
        reason = "AI语义判重";
      } else {
        reason = stringValue(reasonRaw, base + ".reason", tracker);
      }

      matches.add(new ConfigurableHomeworkOrganizerModelClient.DuplicateDecision(
          candidateIndex, assignmentId, confidence, reason));
    }

    return new Result(
        new ConfigurableHomeworkOrganizerModelClient.DuplicateReviewResult(List.copyOf(matches)),
        normalized.shape(),
        tracker.paths());
  }

  private static List<?> matchList(
      JsonMapper mapper, Object value, String path, Tracker tracker) throws Exception {
    if (value instanceof List<?> list) return list;
    if (value instanceof Map<?, ?> map) {
      tracker.add(path);
      return List.of(map);
    }
    if (value instanceof String text) {
      String trimmed = text.trim();
      if (trimmed.startsWith("[") || trimmed.startsWith("{") || trimmed.startsWith("```")) {
        tracker.add(path);
        String unfenced = trimmed;
        if (unfenced.startsWith("```")) {
          int firstNewline = unfenced.indexOf('\n');
          int lastFence = unfenced.lastIndexOf("```");
          if (firstNewline >= 0 && lastFence > firstNewline) {
            unfenced = unfenced.substring(firstNewline + 1, lastFence).trim();
          }
        }
        Object nested = mapper.readValue(unfenced, Object.class);
        if (nested instanceof List<?> list) return list;
        if (nested instanceof Map<?, ?> map) return List.of(map);
      }
    }
    throw invalid(path, "must be an array, one match object, or structured JSON text");
  }

  private static int candidateIndex(Object value, String path, Tracker tracker) {
    Object scalar = unwrapScalar(value, path, tracker, "value", "index", "candidateIndex", "candidate");
    if (scalar instanceof Number number) return exactInteger(number.toString(), path);
    if (scalar instanceof String text) {
      String normalized = text.trim();
      if (normalized.matches("[cC]\\d+")) {
        tracker.add(path);
        normalized = normalized.substring(1);
      } else if (!normalized.equals(text)) {
        tracker.add(path);
      }
      return exactInteger(normalized, path);
    }
    throw invalid(path, "must be an integer or C-prefixed integer");
  }

  private static double confidenceValue(Object value, String path, Tracker tracker) {
    Object scalar = unwrapScalar(value, path, tracker, "value", "confidence", "score");
    String text;
    if (scalar instanceof Number number) {
      text = number.toString();
    } else if (scalar instanceof String string) {
      text = string.trim();
      if (!text.equals(string)) tracker.add(path);
    } else {
      throw invalid(path, "must be a number");
    }

    boolean percent = text.endsWith("%");
    if (percent) {
      tracker.add(path);
      text = text.substring(0, text.length() - 1).trim();
    }
    try {
      double parsed = new BigDecimal(text).doubleValue();
      if (percent) parsed /= 100.0;
      if (parsed < 0.0 || parsed > 1.0) {
        throw invalid(path, "must be between 0 and 1");
      }
      return parsed;
    } catch (NumberFormatException error) {
      throw invalid(path, "must be a valid number");
    }
  }

  private static String stringValue(Object value, String path, Tracker tracker) {
    Object scalar = unwrapScalar(value, path, tracker,
        "value", "text", "content", "id", "reason", "duplicateAssignmentId");
    if (scalar instanceof String text) {
      String trimmed = text.trim();
      if (!trimmed.equals(text)) tracker.add(path);
      if (trimmed.isBlank()) throw invalid(path, "must not be blank");
      return trimmed;
    }
    if (scalar instanceof Number number) {
      tracker.add(path);
      return number.toString();
    }
    throw invalid(path, "must be a string or supported scalar wrapper");
  }

  private static Object unwrapScalar(
      Object value, String path, Tracker tracker, String... wrapperKeys) {
    Object current = value;
    for (int depth = 0; depth <= 4; depth++) {
      if (current instanceof List<?> list) {
        if (list.size() != 1) throw invalid(path, "scalar list wrapper must contain exactly one item");
        tracker.add(path);
        current = list.get(0);
        continue;
      }
      if (!(current instanceof Map<?, ?>)) return current;

      Map<String, Object> object = objectMap(current, path);
      List<Object> candidates = new ArrayList<>();
      for (String key : wrapperKeys) {
        if (object.containsKey(key) && object.get(key) != null) {
          candidates.add(object.get(key));
        }
      }
      if (candidates.isEmpty()) {
        throw invalid(path, "does not contain a supported scalar wrapper key");
      }
      Object first = candidates.get(0);
      for (Object candidate : candidates) {
        if (!Objects.deepEquals(first, candidate)) {
          throw invalid(path, "contains conflicting scalar wrapper values");
        }
      }
      tracker.add(path);
      current = first;
    }
    throw invalid(path, "wrapper nesting is too deep");
  }

  private static Object pick(Map<String, Object> object, String path, String... keys) {
    Object value = pickOptional(object, keys);
    if (value == null) throw invalid(path, "is required; availableFields=" + object.keySet());
    return value;
  }

  private static Object pickOptional(Map<String, Object> object, String... keys) {
    Object selected = null;
    String selectedKey = null;
    for (String key : keys) {
      if (!object.containsKey(key) || object.get(key) == null) continue;
      if (selected == null) {
        selected = object.get(key);
        selectedKey = key;
        continue;
      }
      if (!Objects.deepEquals(selected, object.get(key))) {
        throw invalid("$", "contains conflicting aliases " + selectedKey + " and " + key);
      }
    }
    return selected;
  }

  private static int exactInteger(String value, String path) {
    try {
      return new BigDecimal(value.trim()).intValueExact();
    } catch (Exception error) {
      throw invalid(path, "must be an exact integer");
    }
  }

  private static Map<String, Object> objectMap(Object value, String path) {
    if (!(value instanceof Map<?, ?> source)) throw invalid(path, "must be an object");
    Map<String, Object> result = new LinkedHashMap<>();
    for (Map.Entry<?, ?> entry : source.entrySet()) {
      if (!(entry.getKey() instanceof String key)) {
        throw invalid(path, "contains a non-string object key");
      }
      result.put(key, entry.getValue());
    }
    return result;
  }

  private static IllegalArgumentException invalid(String path, String message) {
    return new IllegalArgumentException(path + " " + message);
  }

  private static final class Tracker {
    private final LinkedHashSet<String> paths = new LinkedHashSet<>();
    void add(String path) { paths.add(path); }
    List<String> paths() { return List.copyOf(paths); }
  }
}
