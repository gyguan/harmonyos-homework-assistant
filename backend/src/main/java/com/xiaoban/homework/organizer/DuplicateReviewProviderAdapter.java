package com.xiaoban.homework.organizer;

import com.xiaoban.homework.ai.StructuredJsonNormalizer;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import tools.jackson.databind.json.JsonMapper;

/**
 * Canonical parser for duplicate-review output.
 *
 * <p>Provider/model-specific field aliases are intentionally not supported here. Transport-level
 * structured output and one bounded format-repair attempt own provider variation. This adapter
 * accepts only the business contract field names so switching models cannot grow alias lists in
 * domain code.
 */
final class DuplicateReviewProviderAdapter {
  private static final Set<String> ROOT_FIELDS = Set.of("matches");
  private static final Set<String> MATCH_FIELDS =
      Set.of("candidateIndex", "duplicateAssignmentId", "confidence", "reason");

  private DuplicateReviewProviderAdapter() {}

  record Result(
      ConfigurableHomeworkOrganizerModelClient.DuplicateReviewResult review,
      String shape,
      List<String> coercedPaths) {}

  static Result adapt(JsonMapper mapper, String raw) throws Exception {
    StructuredJsonNormalizer.Result normalized = StructuredJsonNormalizer.normalize(mapper, raw);
    Object parsed = mapper.readValue(normalized.json(), Object.class);
    Map<String, Object> root = objectMap(parsed, "$");
    rejectUnexpectedFields(root, ROOT_FIELDS, "$");

    Object matchesValue = requiredValue(root, "matches", "$.matches");
    if (!(matchesValue instanceof List<?> source)) {
      throw invalid("$.matches", "must be an array");
    }

    Tracker tracker = new Tracker();
    List<ConfigurableHomeworkOrganizerModelClient.DuplicateDecision> matches = new ArrayList<>();
    for (int i = 0; i < source.size(); i++) {
      String base = "$.matches[" + i + "]";
      Map<String, Object> item = objectMap(source.get(i), base);
      rejectUnexpectedFields(item, MATCH_FIELDS, base);

      int candidateIndex = exactInteger(
          requiredValue(item, "candidateIndex", base + ".candidateIndex"),
          base + ".candidateIndex", tracker);
      String assignmentId = exactString(
          requiredValue(item, "duplicateAssignmentId", base + ".duplicateAssignmentId"),
          base + ".duplicateAssignmentId", tracker);
      double confidence = exactConfidence(
          requiredValue(item, "confidence", base + ".confidence"),
          base + ".confidence", tracker);
      String reason = exactString(
          requiredValue(item, "reason", base + ".reason"),
          base + ".reason", tracker);

      matches.add(new ConfigurableHomeworkOrganizerModelClient.DuplicateDecision(
          candidateIndex, assignmentId, confidence, reason));
    }

    return new Result(
        new ConfigurableHomeworkOrganizerModelClient.DuplicateReviewResult(List.copyOf(matches)),
        normalized.shape(),
        tracker.paths());
  }

  private static int exactInteger(Object value, String path, Tracker tracker) {
    if (value instanceof Number number) {
      try {
        return new BigDecimal(number.toString()).intValueExact();
      } catch (Exception error) {
        throw invalid(path, "must be an exact integer");
      }
    }
    if (value instanceof String text) {
      tracker.add(path);
      try {
        return new BigDecimal(text.trim()).intValueExact();
      } catch (Exception error) {
        throw invalid(path, "must be an exact integer");
      }
    }
    throw invalid(path, "must be an integer");
  }

  private static double exactConfidence(Object value, String path, Tracker tracker) {
    String text;
    if (value instanceof Number number) {
      text = number.toString();
    } else if (value instanceof String string) {
      tracker.add(path);
      text = string.trim();
    } else {
      throw invalid(path, "must be a number");
    }
    try {
      double parsed = new BigDecimal(text).doubleValue();
      if (parsed < 0.0 || parsed > 1.0) throw invalid(path, "must be between 0 and 1");
      return parsed;
    } catch (NumberFormatException error) {
      throw invalid(path, "must be a valid number");
    }
  }

  private static String exactString(Object value, String path, Tracker tracker) {
    if (value instanceof String text) {
      String trimmed = text.trim();
      if (!trimmed.equals(text)) tracker.add(path);
      if (trimmed.isBlank()) throw invalid(path, "must not be blank");
      return trimmed;
    }
    throw invalid(path, "must be a string");
  }

  private static Object requiredValue(Map<String, Object> object, String field, String path) {
    if (!object.containsKey(field) || object.get(field) == null) {
      throw invalid(path, "is required; availableFields=" + object.keySet());
    }
    return object.get(field);
  }

  private static void rejectUnexpectedFields(
      Map<String, Object> object, Set<String> allowed, String path) {
    List<String> unexpected = object.keySet().stream()
        .filter(key -> !allowed.contains(key))
        .toList();
    if (!unexpected.isEmpty()) {
      throw invalid(path, "contains unexpected fields " + unexpected);
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
    private final java.util.LinkedHashSet<String> paths = new java.util.LinkedHashSet<>();
    void add(String path) { paths.add(path); }
    List<String> paths() { return List.copyOf(paths); }
  }
}
