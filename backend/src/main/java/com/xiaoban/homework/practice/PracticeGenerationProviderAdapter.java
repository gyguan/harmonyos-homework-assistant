package com.xiaoban.homework.practice;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import tools.jackson.databind.json.JsonMapper;

/**
 * Provider compatibility boundary for generated practice content.
 *
 * It accepts a small, provider-neutral set of common JSON variations and emits exactly one
 * canonical contract. It never performs subject/business validation; that remains downstream.
 */
final class PracticeGenerationProviderAdapter {
  private static final List<String> LABEL_KEYS = List.of(
      "label", "text", "value", "content", "name");
  private static final List<String> ANSWER_KEYS = List.of(
      "answerSpec", "answer", "value", "text", "content");

  private final JsonMapper mapper;

  PracticeGenerationProviderAdapter(JsonMapper mapper) {
    this.mapper = mapper;
  }

  record Result(PracticeGenerationContract.Paper paper, List<String> adaptations) {}
  private record OptionSet(
      List<PracticeGenerationContract.Option> options,
      Map<String, String> answerAliases) {}

  Result adapt(String json) throws Exception {
    PracticeGenerationPayloadNormalizer.Result scalarNormalized =
        PracticeGenerationPayloadNormalizer.normalize(mapper, json);

    Object parsed = mapper.readValue(scalarNormalized.json(), Object.class);
    if (!(parsed instanceof Map<?, ?> rawRoot)) {
      throw new IllegalArgumentException("practice provider payload root must be an object");
    }

    List<String> adaptations = new ArrayList<>(scalarNormalized.coercedPaths());
    Map<String, Object> root = stringKeyMap(rawRoot);

    String title = requiredString(root.get("title"), "$.title");
    String description = requiredString(root.get("description"), "$.description");
    int estimatedMinutes = requiredInteger(root.get("estimatedMinutes"), "$.estimatedMinutes");
    List<String> tags = requiredStringList(root.get("tags"), "$.tags");
    List<PracticeGenerationContract.Question> questions =
        adaptQuestions(root.get("questions"), adaptations);

    return new Result(
        new PracticeGenerationContract.Paper(
            title, description, estimatedMinutes, tags, questions),
        List.copyOf(adaptations));
  }

  private List<PracticeGenerationContract.Question> adaptQuestions(
      Object value, List<String> adaptations) {
    if (!(value instanceof List<?> sourceQuestions)) {
      throw new IllegalArgumentException("$.questions must be an array");
    }

    List<PracticeGenerationContract.Question> questions = new ArrayList<>();
    for (int i = 0; i < sourceQuestions.size(); i++) {
      Object item = sourceQuestions.get(i);
      String path = "$.questions[" + i + "]";
      if (!(item instanceof Map<?, ?> rawQuestion)) {
        throw new IllegalArgumentException(path + " must be an object");
      }
      Map<String, Object> question = stringKeyMap(rawQuestion);

      String type = canonicalQuestionType(requiredString(question.get("type"), path + ".type"));
      String stem = requiredString(question.get("stem"), path + ".stem");
      OptionSet optionSet =
          adaptOptions(question.get("options"), path + ".options", adaptations);
      List<PracticeGenerationContract.Option> options = optionSet.options();
      String answerSpec = requiredStringFromAliases(question, ANSWER_KEYS, path + ".answerSpec");
      String explanation = requiredString(question.get("explanation"), path + ".explanation");
      List<String> hints = requiredStringList(question.get("hints"), path + ".hints");
      List<String> tags = requiredStringList(question.get("tags"), path + ".tags");

      if ("SINGLE_CHOICE".equals(type)) {
        String canonicalAnswer = canonicalChoiceAnswer(
            answerSpec, options, optionSet.answerAliases());
        if (!canonicalAnswer.equals(answerSpec)) {
          adaptations.add(path + ".answerSpec(label->key)");
          answerSpec = canonicalAnswer;
        }
      }

      questions.add(new PracticeGenerationContract.Question(
          type, stem, options, answerSpec, explanation, hints, tags));
    }
    return questions;
  }

  private OptionSet adaptOptions(
      Object value, String path, List<String> adaptations) {
    if (value == null) return new OptionSet(List.of(), Map.of());

    if (value instanceof Map<?, ?> rawMap) {
      Map<String, Object> source = stringKeyMap(rawMap);
      List<PracticeGenerationContract.Option> options = new ArrayList<>();
      Map<String, String> aliases = new LinkedHashMap<>();
      for (Map.Entry<String, Object> entry : source.entrySet()) {
        String originalKey = entry.getKey().trim();
        String key = canonicalOptionKey(originalKey, options.size());
        String label = requiredString(entry.getValue(), path + "." + entry.getKey());
        options.add(new PracticeGenerationContract.Option(key, label));
        aliases.put(originalKey, key);
        aliases.put(label.trim(), key);
      }
      adaptations.add(path + "(map->options)");
      return new OptionSet(options, aliases);
    }

    if (!(value instanceof List<?> source)) {
      throw new IllegalArgumentException(path + " must be an array or object");
    }

    List<PracticeGenerationContract.Option> options = new ArrayList<>();
    Map<String, String> aliases = new LinkedHashMap<>();
    for (int i = 0; i < source.size(); i++) {
      Object item = source.get(i);
      String itemPath = path + "[" + i + "]";

      if (isScalar(item)) {
        String key = optionKey(i);
        String label = String.valueOf(item);
        options.add(new PracticeGenerationContract.Option(key, label));
        aliases.put(label.trim(), key);
        adaptations.add(itemPath + "(scalar->option)");
        continue;
      }

      if (!(item instanceof Map<?, ?> rawOption)) {
        throw new IllegalArgumentException(itemPath + " must be an option object or scalar");
      }
      Map<String, Object> option = stringKeyMap(rawOption);

      String key = optionalString(option.get("key"));
      String label = optionalStringFromAliases(option, LABEL_KEYS);

      if (label == null && option.size() == 1) {
        Map.Entry<String, Object> only = option.entrySet().iterator().next();
        if (looksLikeOptionKey(only.getKey()) && isScalar(only.getValue())) {
          key = only.getKey();
          label = String.valueOf(only.getValue());
          adaptations.add(itemPath + "(single-entry->option)");
        }
      }

      if (label == null) {
        throw new IllegalArgumentException(itemPath + " is missing an option label");
      }
      String originalKey = key == null ? "" : key.trim();
      if (originalKey.isBlank()) {
        key = optionKey(i);
        adaptations.add(itemPath + ".key(auto)");
      } else {
        key = canonicalOptionKey(originalKey, i);
        aliases.put(originalKey, key);
      }
      aliases.put(label.trim(), key);
      options.add(new PracticeGenerationContract.Option(key, label));
    }
    return new OptionSet(options, aliases);
  }

  private static String canonicalChoiceAnswer(
      String answerSpec,
      List<PracticeGenerationContract.Option> options,
      Map<String, String> aliases) {
    String answer = answerSpec.trim();

    for (PracticeGenerationContract.Option option : options) {
      if (option.key().equalsIgnoreCase(answer)) return option.key();
    }

    String aliasMatch = aliases.get(answer);
    if (aliasMatch != null) return aliasMatch;

    PracticeGenerationContract.Option matched = null;
    for (PracticeGenerationContract.Option option : options) {
      if (!option.label().trim().equals(answer)) continue;
      if (matched != null) {
        throw new IllegalArgumentException(
            "choice answer text matches multiple option labels");
      }
      matched = option;
    }
    return matched == null ? answer : matched.key();
  }

  private static String canonicalQuestionType(String value) {
    String normalized = value.trim()
        .toUpperCase(Locale.ROOT)
        .replace('-', '_')
        .replace(' ', '_');

    return switch (normalized) {
      case "SINGLE_CHOICE", "SINGLECHOICE", "CHOICE", "单选", "单选题" -> "SINGLE_CHOICE";
      case "FILL_BLANK", "FILLBLANK", "FILL_IN_THE_BLANK", "填空", "填空题" -> "FILL_BLANK";
      case "NUMBER", "NUMERIC", "CALCULATION", "计算", "计算题" -> "NUMBER";
      default -> value.trim();
    };
  }

  private static String canonicalOptionKey(String value, int index) {
    String key = value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
    if (looksLikeOptionKey(key)) return key;
    return optionKey(index);
  }

  private static boolean looksLikeOptionKey(String value) {
    if (value == null) return false;
    String key = value.trim().toUpperCase(Locale.ROOT);
    return key.length() == 1 && key.charAt(0) >= 'A' && key.charAt(0) <= 'D';
  }

  private static String optionKey(int index) {
    if (index < 0 || index > 3) {
      throw new IllegalArgumentException("single choice supports at most 4 options");
    }
    return String.valueOf((char) ('A' + index));
  }

  private static String requiredStringFromAliases(
      Map<String, Object> source, List<String> aliases, String path) {
    for (String alias : aliases) {
      if (!source.containsKey(alias)) continue;
      String value = optionalString(source.get(alias));
      if (value != null) return value;
    }
    throw new IllegalArgumentException(path + " must be a scalar string");
  }

  private static String optionalStringFromAliases(
      Map<String, Object> source, List<String> aliases) {
    for (String alias : aliases) {
      if (!source.containsKey(alias)) continue;
      String value = optionalString(source.get(alias));
      if (value != null) return value;
    }
    return null;
  }

  private static String requiredString(Object value, String path) {
    String result = optionalString(value);
    if (result == null) throw new IllegalArgumentException(path + " must be a scalar string");
    return result;
  }

  private static String optionalString(Object value) {
    if (value instanceof String text) return text;
    if (value instanceof Number || value instanceof Boolean) return String.valueOf(value);
    return null;
  }

  private static int requiredInteger(Object value, String path) {
    if (value instanceof Number number) return number.intValue();
    if (value instanceof String text) {
      try {
        return Integer.parseInt(text.trim());
      } catch (NumberFormatException ignored) {
        // handled below
      }
    }
    throw new IllegalArgumentException(path + " must be an integer");
  }

  private static List<String> requiredStringList(Object value, String path) {
    if (!(value instanceof List<?> source)) {
      throw new IllegalArgumentException(path + " must be an array");
    }
    List<String> result = new ArrayList<>();
    for (int i = 0; i < source.size(); i++) {
      result.add(requiredString(source.get(i), path + "[" + i + "]"));
    }
    return result;
  }

  private static boolean isScalar(Object value) {
    return value instanceof String || value instanceof Number || value instanceof Boolean;
  }

  private static Map<String, Object> stringKeyMap(Map<?, ?> source) {
    Map<String, Object> result = new LinkedHashMap<>();
    for (Map.Entry<?, ?> entry : source.entrySet()) {
      if (entry.getKey() instanceof String key) result.put(key, entry.getValue());
    }
    return result;
  }
}
