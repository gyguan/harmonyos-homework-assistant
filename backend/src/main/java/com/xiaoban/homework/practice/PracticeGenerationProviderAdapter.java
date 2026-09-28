package com.xiaoban.homework.practice;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import tools.jackson.databind.json.JsonMapper;

/**
 * Adapts bounded provider response variations into the single canonical Practice generation contract.
 *
 * <p>This is the only layer allowed to understand provider response shape differences. It is
 * intentionally fail-closed: unsupported or ambiguous structures are rejected rather than guessed.
 */
final class PracticeGenerationProviderAdapter {
  private static final List<String> STRING_WRAPPER_KEYS = List.of(
      "text", "value", "content", "answer", "label", "key", "type", "name");
  private static final List<String> INTEGER_WRAPPER_KEYS = List.of(
      "value", "minutes", "estimatedMinutes");

  private PracticeGenerationProviderAdapter() {}

  record Result(
      PracticeGenerationCanonicalContract.Paper paper,
      List<String> coercedPaths) {}

  private record AdaptedOptions(
      List<PracticeGenerationCanonicalContract.Option> options,
      Set<String> generatedKeys) {}

  static Result adapt(JsonMapper mapper, String json) throws Exception {
    Object parsed = mapper.readValue(json, Object.class);
    Map<String, Object> root = objectMap(parsed, "$");
    Tracker tracker = new Tracker();

    String title = requiredString(root, "title", "$.title", tracker);
    String description = requiredString(root, "description", "$.description", tracker);
    int estimatedMinutes =
        requiredInteger(root, "estimatedMinutes", "$.estimatedMinutes", tracker);
    List<String> tags = requiredStringList(root, "tags", "$.tags", tracker);
    List<PracticeGenerationCanonicalContract.Question> questions =
        questions(requiredValue(root, "questions", "$.questions"), tracker);

    return new Result(
        new PracticeGenerationCanonicalContract.Paper(
            title, description, estimatedMinutes, tags, questions),
        tracker.paths());
  }

  private static List<PracticeGenerationCanonicalContract.Question> questions(
      Object value, Tracker tracker) {
    if (!(value instanceof List<?> source)) {
      throw invalid("$.questions", "must be an array");
    }

    List<PracticeGenerationCanonicalContract.Question> result = new ArrayList<>();
    for (int i = 0; i < source.size(); i++) {
      String base = "$.questions[" + i + "]";
      Map<String, Object> question = objectMap(source.get(i), base);
      String type = normalizeQuestionType(
          requiredString(question, "type", base + ".type", tracker),
          base + ".type",
          tracker);
      String stem = requiredString(question, "stem", base + ".stem", tracker);
      AdaptedOptions adaptedOptions =
          options(requiredValue(question, "options", base + ".options"), base + ".options", tracker);
      List<PracticeGenerationCanonicalContract.Option> options = adaptedOptions.options();
      String answerSpec = normalizeAnswerSpec(
          type,
          requiredString(question, "answerSpec", base + ".answerSpec", tracker),
          adaptedOptions,
          base + ".answerSpec",
          tracker);
      String explanation =
          requiredString(question, "explanation", base + ".explanation", tracker);
      List<String> hints =
          requiredStringList(question, "hints", base + ".hints", tracker);
      List<String> tags =
          requiredStringList(question, "tags", base + ".tags", tracker);

      result.add(new PracticeGenerationCanonicalContract.Question(
          type, stem, options, answerSpec, explanation, hints, tags));
    }
    return List.copyOf(result);
  }

  private static AdaptedOptions options(
      Object value, String path, Tracker tracker) {
    List<PracticeGenerationCanonicalContract.Option> result = new ArrayList<>();
    Set<String> generatedKeys = new LinkedHashSet<>();

    if (value instanceof List<?> source) {
      for (int i = 0; i < source.size(); i++) {
        String optionPath = path + "[" + i + "]";
        Object item = source.get(i);

        if (item instanceof Map<?, ?>) {
          Map<String, Object> option = objectMap(item, optionPath);
          if (option.containsKey("key") || option.containsKey("label")) {
            if (!option.containsKey("label")) {
              throw invalid(optionPath + ".label", "is required when option is an object");
            }
            String label = stringValue(option.get("label"), optionPath + ".label", tracker);
            String key;
            if (option.containsKey("key")) {
              key = normalizeOptionKey(
                  stringValue(option.get("key"), optionPath + ".key", tracker),
                  optionPath + ".key",
                  tracker);
            } else {
              key = generatedOptionKey(i, optionPath + ".key");
              generatedKeys.add(key);
              tracker.add(optionPath + ".key");
            }
            result.add(new PracticeGenerationCanonicalContract.Option(key, label));
            continue;
          }
        }

        String label = stringValue(item, optionPath, tracker);
        String generatedKey = generatedOptionKey(i, optionPath + ".key");
        generatedKeys.add(generatedKey);
        result.add(new PracticeGenerationCanonicalContract.Option(generatedKey, label));
        tracker.add(optionPath);
      }
    } else if (value instanceof Map<?, ?>) {
      Map<String, Object> source = objectMap(value, path);
      for (Map.Entry<String, Object> entry : source.entrySet()) {
        String optionPath = path + "." + entry.getKey();
        String key = normalizeOptionKey(entry.getKey(), optionPath + ".key", tracker);
        String label = stringValue(entry.getValue(), optionPath + ".label", tracker);
        result.add(new PracticeGenerationCanonicalContract.Option(key, label));
      }
      tracker.add(path);
    } else {
      throw invalid(path, "must be an array or key-label object");
    }

    Set<String> keys = new LinkedHashSet<>();
    for (PracticeGenerationCanonicalContract.Option option : result) {
      if (!keys.add(option.key())) {
        throw invalid(path, "contains duplicate option key " + option.key());
      }
    }
    return new AdaptedOptions(List.copyOf(result), Set.copyOf(generatedKeys));
  }

  private static String normalizeAnswerSpec(
      String type,
      String answerSpec,
      AdaptedOptions adaptedOptions,
      String path,
      Tracker tracker) {
    if (!"SINGLE_CHOICE".equals(type)) return answerSpec;

    List<PracticeGenerationCanonicalContract.Option> options = adaptedOptions.options();
    String normalizedKey = answerSpec.trim().toUpperCase(Locale.ROOT);
    PracticeGenerationCanonicalContract.Option keyMatch = options.stream()
        .filter(option -> option.key().equals(normalizedKey))
        .findFirst()
        .orElse(null);

    List<PracticeGenerationCanonicalContract.Option> labelMatches = options.stream()
        .filter(option -> option.label().equals(answerSpec))
        .toList();
    if (labelMatches.size() > 1) {
      throw invalid(path, "matches multiple option labels");
    }

    if (keyMatch != null) {
      if (adaptedOptions.generatedKeys().contains(keyMatch.key())
          && labelMatches.size() == 1
          && !labelMatches.get(0).key().equals(keyMatch.key())) {
        tracker.add(path);
        return labelMatches.get(0).key();
      }
      if (!answerSpec.equals(keyMatch.key())) tracker.add(path);
      return keyMatch.key();
    }

    if (labelMatches.size() == 1) {
      tracker.add(path);
      return labelMatches.get(0).key();
    }
    throw invalid(path, "must match an option key or one unique option label");
  }

  private static String normalizeQuestionType(String raw, String path, Tracker tracker) {
    String compact = raw.trim()
        .toUpperCase(Locale.ROOT)
        .replaceAll("[^A-Z0-9]", "");
    String normalized = switch (compact) {
      case "SINGLECHOICE" -> "SINGLE_CHOICE";
      case "FILLBLANK" -> "FILL_BLANK";
      case "NUMBER" -> "NUMBER";
      default -> throw invalid(path, "unsupported question type " + raw);
    };
    if (!raw.equals(normalized)) tracker.add(path);
    return normalized;
  }

  private static String normalizeOptionKey(String raw, String path, Tracker tracker) {
    String normalized = raw.trim().toUpperCase(Locale.ROOT);
    if (!normalized.matches("[A-D]")) {
      throw invalid(path, "option key must be one of A/B/C/D");
    }
    if (!raw.equals(normalized)) tracker.add(path);
    return normalized;
  }

  private static String generatedOptionKey(int index, String path) {
    if (index < 0 || index >= 4) {
      throw invalid(path, "cannot auto-generate option key beyond D");
    }
    return String.valueOf((char) ('A' + index));
  }

  private static String requiredString(
      Map<String, Object> object, String field, String path, Tracker tracker) {
    return stringValue(requiredValue(object, field, path), path, tracker);
  }

  private static int requiredInteger(
      Map<String, Object> object, String field, String path, Tracker tracker) {
    Object value = requiredValue(object, field, path);
    if (value instanceof Number number) {
      return exactInteger(number.toString(), path);
    }
    if (value instanceof String text) {
      tracker.add(path);
      return exactInteger(text, path);
    }
    if (value instanceof Map<?, ?>) {
      tracker.add(path);
      return wrappedInteger(value, path, 0);
    }
    throw invalid(path, "must be an integer");
  }

  private static List<String> requiredStringList(
      Map<String, Object> object, String field, String path, Tracker tracker) {
    Object value = requiredValue(object, field, path);
    if (!(value instanceof List<?> source)) {
      throw invalid(path, "must be an array");
    }
    List<String> result = new ArrayList<>();
    for (int i = 0; i < source.size(); i++) {
      result.add(stringValue(source.get(i), path + "[" + i + "]", tracker));
    }
    return List.copyOf(result);
  }

  private static String stringValue(Object value, String path, Tracker tracker) {
    if (value instanceof String text) {
      String trimmed = text.trim();
      if (!trimmed.equals(text)) tracker.add(path);
      return trimmed;
    }
    if (value instanceof Number || value instanceof Boolean) {
      tracker.add(path);
      return String.valueOf(value);
    }
    if (value instanceof Map<?, ?>) {
      tracker.add(path);
      return wrappedString(value, path, 0);
    }
    throw invalid(path, "must be a string or supported scalar wrapper");
  }

  private static String wrappedString(Object value, String path, int depth) {
    if (depth > 4) throw invalid(path, "wrapper nesting is too deep");
    if (value instanceof String text) return text.trim();
    if (value instanceof Number || value instanceof Boolean) return String.valueOf(value);
    if (!(value instanceof Map<?, ?>)) {
      throw invalid(path, "wrapper does not contain a scalar value");
    }

    Map<String, Object> object = objectMap(value, path);
    List<String> candidates = new ArrayList<>();
    for (String key : STRING_WRAPPER_KEYS) {
      if (object.containsKey(key)) {
        candidates.add(wrappedString(object.get(key), path + "." + key, depth + 1));
      }
    }
    return uniqueCandidate(candidates, path);
  }

  private static int wrappedInteger(Object value, String path, int depth) {
    if (depth > 4) throw invalid(path, "wrapper nesting is too deep");
    if (value instanceof Number number) return exactInteger(number.toString(), path);
    if (value instanceof String text) return exactInteger(text, path);
    if (!(value instanceof Map<?, ?>)) {
      throw invalid(path, "wrapper does not contain an integer value");
    }

    Map<String, Object> object = objectMap(value, path);
    List<Integer> candidates = new ArrayList<>();
    for (String key : INTEGER_WRAPPER_KEYS) {
      if (object.containsKey(key)) {
        candidates.add(wrappedInteger(object.get(key), path + "." + key, depth + 1));
      }
    }
    if (candidates.isEmpty()) {
      throw invalid(path, "does not contain a supported integer wrapper key");
    }
    int first = candidates.get(0);
    for (int candidate : candidates) {
      if (candidate != first) {
        throw invalid(path, "contains conflicting integer wrapper values");
      }
    }
    return first;
  }

  private static String uniqueCandidate(List<String> candidates, String path) {
    if (candidates.isEmpty()) {
      throw invalid(path, "does not contain a supported scalar wrapper key");
    }
    String first = candidates.get(0);
    for (String candidate : candidates) {
      if (!candidate.equals(first)) {
        throw invalid(path, "contains conflicting scalar wrapper values");
      }
    }
    return first;
  }

  private static int exactInteger(String value, String path) {
    try {
      return new BigDecimal(value.trim()).intValueExact();
    } catch (Exception error) {
      throw invalid(path, "must be an exact integer");
    }
  }

  private static Object requiredValue(Map<String, Object> object, String field, String path) {
    if (!object.containsKey(field) || object.get(field) == null) {
      throw invalid(path, "is required");
    }
    return object.get(field);
  }

  private static Map<String, Object> objectMap(Object value, String path) {
    if (!(value instanceof Map<?, ?> source)) {
      throw invalid(path, "must be an object");
    }
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

    void add(String path) {
      paths.add(path);
    }

    List<String> paths() {
      return List.copyOf(paths);
    }
  }
}
