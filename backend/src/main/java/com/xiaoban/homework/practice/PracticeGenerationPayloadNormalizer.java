package com.xiaoban.homework.practice;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import tools.jackson.databind.json.JsonMapper;

/**
 * Normalizes provider-specific scalar wrappers inside an otherwise valid practice paper object.
 * Only known scalar fields are touched; unknown/complex values are rejected later by typed mapping.
 */
final class PracticeGenerationPayloadNormalizer {
  private static final List<String> STRING_WRAPPER_KEYS = List.of(
      "text", "value", "content", "answer", "label", "key", "type", "name");
  private static final List<String> INTEGER_WRAPPER_KEYS = List.of(
      "value", "minutes", "estimatedMinutes");

  private PracticeGenerationPayloadNormalizer() {}

  record Result(String json, List<String> coercedPaths) {}

  static Result normalize(JsonMapper mapper, String json) throws Exception {
    Object parsed = mapper.readValue(json, Object.class);
    if (!(parsed instanceof Map<?, ?> rawRoot)) {
      throw new IllegalArgumentException("practice payload root must be an object");
    }

    List<String> coerced = new ArrayList<>();
    Map<String, Object> root = stringKeyMap(rawRoot);

    normalizeStringField(root, "title", "$.title", coerced);
    normalizeStringField(root, "description", "$.description", coerced);
    normalizeIntegerField(root, "estimatedMinutes", "$.estimatedMinutes", coerced);
    normalizeStringListField(root, "tags", "$.tags", coerced);

    Object questionsValue = root.get("questions");
    if (questionsValue instanceof List<?> questions) {
      List<Object> normalizedQuestions = new ArrayList<>();
      for (int i = 0; i < questions.size(); i++) {
        Object questionValue = questions.get(i);
        if (!(questionValue instanceof Map<?, ?> rawQuestion)) {
          normalizedQuestions.add(questionValue);
          continue;
        }
        Map<String, Object> question = stringKeyMap(rawQuestion);
        String base = "$.questions[" + i + "]";
        normalizeStringField(question, "type", base + ".type", coerced);
        normalizeStringField(question, "stem", base + ".stem", coerced);
        normalizeStringField(question, "answerSpec", base + ".answerSpec", coerced);
        normalizeStringField(question, "explanation", base + ".explanation", coerced);
        normalizeStringListField(question, "hints", base + ".hints", coerced);
        normalizeStringListField(question, "tags", base + ".tags", coerced);

        Object optionsValue = question.get("options");
        if (optionsValue instanceof List<?> options) {
          List<Object> normalizedOptions = new ArrayList<>();
          for (int j = 0; j < options.size(); j++) {
            Object optionValue = options.get(j);
            if (!(optionValue instanceof Map<?, ?> rawOption)) {
              normalizedOptions.add(optionValue);
              continue;
            }
            Map<String, Object> option = stringKeyMap(rawOption);
            String optionBase = base + ".options[" + j + "]";
            normalizeStringField(option, "key", optionBase + ".key", coerced);
            normalizeStringField(option, "label", optionBase + ".label", coerced);
            normalizedOptions.add(option);
          }
          question.put("options", normalizedOptions);
        }
        normalizedQuestions.add(question);
      }
      root.put("questions", normalizedQuestions);
    }

    return new Result(mapper.writeValueAsString(root), List.copyOf(coerced));
  }

  private static void normalizeStringField(
      Map<String, Object> object, String field, String path, List<String> coerced) {
    if (!object.containsKey(field)) return;
    Object value = object.get(field);
    Object normalized = scalarString(value);
    if (normalized != value) {
      object.put(field, normalized);
      coerced.add(path);
    }
  }

  private static void normalizeIntegerField(
      Map<String, Object> object, String field, String path, List<String> coerced) {
    if (!object.containsKey(field)) return;
    Object value = object.get(field);
    Object normalized = integerValue(value);
    if (normalized != value) {
      object.put(field, normalized);
      coerced.add(path);
    }
  }

  private static void normalizeStringListField(
      Map<String, Object> object, String field, String path, List<String> coerced) {
    Object value = object.get(field);
    if (!(value instanceof List<?> values)) return;

    List<Object> normalized = new ArrayList<>();
    boolean changed = false;
    for (int i = 0; i < values.size(); i++) {
      Object item = values.get(i);
      Object normalizedItem = scalarString(item);
      normalized.add(normalizedItem);
      if (normalizedItem != item) {
        coerced.add(path + "[" + i + "]");
        changed = true;
      }
    }
    if (changed) object.put(field, normalized);
  }

  private static Object scalarString(Object value) {
    return scalarString(value, 0);
  }

  private static Object scalarString(Object value, int depth) {
    if (depth > 3 || !(value instanceof Map<?, ?> rawMap)) return value;
    Map<String, Object> map = stringKeyMap(rawMap);
    for (String key : STRING_WRAPPER_KEYS) {
      if (!map.containsKey(key)) continue;
      Object nested = map.get(key);
      if (nested instanceof String || nested instanceof Number || nested instanceof Boolean) {
        return String.valueOf(nested);
      }
      Object unwrapped = scalarString(nested, depth + 1);
      if (unwrapped != nested) return unwrapped;
    }
    if (map.size() == 1) {
      Object only = map.values().iterator().next();
      if (only instanceof String || only instanceof Number || only instanceof Boolean) {
        return String.valueOf(only);
      }
      Object unwrapped = scalarString(only, depth + 1);
      if (unwrapped != only) return unwrapped;
    }
    return value;
  }

  private static Object integerValue(Object value) {
    if (value instanceof Number number) return number.intValue();
    if (value instanceof String text) {
      try {
        return Integer.parseInt(text.trim());
      } catch (NumberFormatException ignored) {
        return value;
      }
    }
    if (!(value instanceof Map<?, ?> rawMap)) return value;

    Map<String, Object> map = stringKeyMap(rawMap);
    for (String key : INTEGER_WRAPPER_KEYS) {
      if (!map.containsKey(key)) continue;
      Object nested = integerValue(map.get(key));
      if (nested instanceof Integer) return nested;
    }
    if (map.size() == 1) {
      Object only = integerValue(map.values().iterator().next());
      if (only instanceof Integer) return only;
    }
    return value;
  }

  private static Map<String, Object> stringKeyMap(Map<?, ?> source) {
    Map<String, Object> result = new LinkedHashMap<>();
    for (Map.Entry<?, ?> entry : source.entrySet()) {
      if (entry.getKey() instanceof String key) result.put(key, entry.getValue());
    }
    return result;
  }
}
