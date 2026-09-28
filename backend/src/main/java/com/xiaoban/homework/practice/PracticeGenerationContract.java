package com.xiaoban.homework.practice;

import java.util.List;

/**
 * Canonical internal contract for AI-generated practice content.
 *
 * Provider-specific output variations must be adapted before entering this contract.
 * Downstream validation and publishing only consume this representation.
 */
final class PracticeGenerationContract {
  private PracticeGenerationContract() {}

  record Option(String key, String label) {}

  record Question(
      String type,
      String stem,
      List<Option> options,
      String answerSpec,
      String explanation,
      List<String> hints,
      List<String> tags) {}

  record Paper(
      String title,
      String description,
      int estimatedMinutes,
      List<String> tags,
      List<Question> questions) {}
}
