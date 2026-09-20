package com.xiaoban.homework.practice;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.Set;
import java.util.TreeSet;

public final class PracticeJudgeEngine {
  public boolean isCorrect(String questionType, String answerSpec, String answerValue) {
    String actual = answerValue == null ? "" : answerValue.trim();
    String expected = answerSpec == null ? "" : answerSpec.trim();
    if (actual.isEmpty()) return false;

    return switch (questionType) {
      case "NUMBER" -> numberEquals(expected, actual);
      case "MULTIPLE_CHOICE" -> choiceSet(expected).equals(choiceSet(actual));
      case "SINGLE_CHOICE" -> expected.equalsIgnoreCase(actual);
      case "FILL_BLANK", "SHORT_TEXT" -> textMatches(expected, actual);
      default -> false;
    };
  }

  private boolean numberEquals(String expected, String actual) {
    try {
      return new BigDecimal(expected).compareTo(new BigDecimal(actual)) == 0;
    } catch (NumberFormatException ignored) {
      return false;
    }
  }

  private Set<String> choiceSet(String value) {
    Set<String> result = new TreeSet<>();
    for (String item : value.split(",")) {
      String normalized = item.trim().toUpperCase();
      if (!normalized.isEmpty()) result.add(normalized);
    }
    return result;
  }

  private boolean textMatches(String expected, String actual) {
    String normalizedActual = normalizeText(actual);
    return Arrays.stream(expected.split("\\|"))
        .map(this::normalizeText)
        .anyMatch(normalizedActual::equals);
  }

  private String normalizeText(String value) {
    return value == null ? "" : value.trim().replaceAll("\\s+", " ").toLowerCase();
  }
}
