package com.xiaoban.homework.practice;

import java.util.List;

/**
 * Provider-independent internal contract for AI-generated practice content.
 *
 * <p>Everything after the provider adapter consumes this shape only. Provider-specific response
 * variations must not leak into validation, answer review, publishing, or the Practice domain.
 */
final class PracticeGenerationCanonicalContract {
  private PracticeGenerationCanonicalContract() {}

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
