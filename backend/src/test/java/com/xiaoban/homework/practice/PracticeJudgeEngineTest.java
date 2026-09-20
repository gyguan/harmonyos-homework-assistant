package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class PracticeJudgeEngineTest {
  private final PracticeJudgeEngine judge = new PracticeJudgeEngine();

  @Test
  void judgesNumericAnswersByValue() {
    assertTrue(judge.isCorrect("NUMBER", "6", "6.0"));
    assertFalse(judge.isCorrect("NUMBER", "6", "7"));
  }

  @Test
  void judgesChoicesWithoutCaseNoise() {
    assertTrue(judge.isCorrect("SINGLE_CHOICE", "B", "b"));
    assertTrue(judge.isCorrect("MULTIPLE_CHOICE", "A,C", "c,a"));
    assertFalse(judge.isCorrect("MULTIPLE_CHOICE", "A,C", "A,B"));
  }

  @Test
  void supportsSeveralAcceptedTextAnswers() {
    assertTrue(judge.isCorrect("SHORT_TEXT", "colour|color", " Color "));
    assertFalse(judge.isCorrect("SHORT_TEXT", "colour|color", "blue"));
  }
}
