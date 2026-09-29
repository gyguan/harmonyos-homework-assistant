package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

class PracticeGeneratedContentValidatorTest {
  private final PracticeGeneratedContentValidator validator =
      new PracticeGeneratedContentValidator(new PracticeContentValidator());

  @Test
  void acceptsValidGeneratedMathPaper() {
    assertDoesNotThrow(() -> validator.validate(validPaper("MATH"), 5));
  }

  @Test
  void rejectsVisualDependency() {
    PracticeContentCatalog.Paper base = validPaper("MATH");
    List<PracticeContentCatalog.Question> questions = new ArrayList<>(base.questions());
    PracticeContentCatalog.Question first = questions.get(0);
    questions.set(0, new PracticeContentCatalog.Question(
        first.id(), first.orderNo(), first.type(), "请看图选择正确答案。",
        first.options(), first.answerSpec(), first.explanation(), first.hints(), first.tags()));
    PracticeContentCatalog.Paper invalid = copy(base, questions);
    assertThrows(IllegalStateException.class, () -> validator.validate(invalid, 5));
  }

  @Test
  void rejectsWrongAnswerForSimpleMathNumberQuestion() {
    PracticeContentCatalog.Paper base = validPaper("MATH");
    List<PracticeContentCatalog.Question> questions = new ArrayList<>(base.questions());
    PracticeContentCatalog.Question first = questions.get(0);
    questions.set(0, new PracticeContentCatalog.Question(
        first.id(), first.orderNo(), "NUMBER", "42 - 5 = ?",
        List.of(), "38", "42减5等于38。",
        List.of("关键词：42、减5"), first.tags()));
    PracticeContentCatalog.Paper invalid = copy(base, questions);
    assertThrows(IllegalStateException.class, () -> validator.validate(invalid, 5));
  }

  @Test
  void rejectsEnglishStemWithoutChineseInstruction() {
    PracticeContentCatalog.Paper base = validPaper("ENGLISH");
    List<PracticeContentCatalog.Question> questions = new ArrayList<>(base.questions());
    PracticeContentCatalog.Question first = questions.get(0);
    questions.set(0, new PracticeContentCatalog.Question(
        first.id(), first.orderNo(), first.type(), "Which word means apple?",
        first.options(), first.answerSpec(), first.explanation(), first.hints(), first.tags()));
    PracticeContentCatalog.Paper invalid = copy(base, questions);
    assertThrows(IllegalStateException.class, () -> validator.validate(invalid, 5));
  }

  private PracticeContentCatalog.Paper validPaper(String subject) {
    List<PracticeContentCatalog.Question> questions = new ArrayList<>();
    for (int i = 1; i <= 5; i++) {
      String stem = "ENGLISH".equals(subject)
          ? "请选择表示苹果的英文单词（第" + i + "题）。"
          : "小明有" + (20 + i) + "张卡片，送出5张，还剩多少张？";
      questions.add(new PracticeContentCatalog.Question(
          "ai-test-Q0" + i,
          i,
          "SINGLE_CHOICE",
          stem,
          List.of(
              new PracticeContentCatalog.Option("A", Integer.toString(10 + i)),
              new PracticeContentCatalog.Option("B", Integer.toString(15 + i)),
              new PracticeContentCatalog.Option("C", Integer.toString(20 + i))),
          "B",
          "先找原有数量和送出数量，再做减法。",
          List.of("关键词：原有、送出、还剩"),
          List.of("专项练习")));
    }
    return new PracticeContentCatalog.Paper(
        "ai-test",
        1,
        "G2",
        subject,
        "S1",
        "EXTRACURRICULAR",
        "AI专项练习",
        "根据家长要求生成",
        "L1",
        5,
        10,
        List.of("AI生成"),
        "AI_GENERATED",
        "PUBLISHED",
        questions);
  }

  private PracticeContentCatalog.Paper copy(
      PracticeContentCatalog.Paper source,
      List<PracticeContentCatalog.Question> questions) {
    return new PracticeContentCatalog.Paper(
        source.id(), source.version(), source.grade(), source.subject(), source.semester(),
        source.track(), source.title(), source.description(), source.difficulty(),
        questions.size(), source.estimatedMinutes(), source.tags(), source.sourceType(),
        source.status(), questions);
  }
}
