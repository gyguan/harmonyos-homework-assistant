package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeContentValidatorTest {
  private final JsonMapper mapper = JsonMapper.builder().build();
  private final PracticeContentValidator validator = new PracticeContentValidator();

  @Test
  void canonicalPresetCatalogPassesValidator() throws Exception {
    try (InputStream input = getClass().getClassLoader()
        .getResourceAsStream("practice/preset-catalog.json")) {
      PracticeContentCatalog.Catalog catalog =
          mapper.readValue(input, PracticeContentCatalog.Catalog.class);
      assertDoesNotThrow(() -> validator.validateCatalog(catalog));
    }
  }

  @Test
  void rejectsChoiceAnswerThatDoesNotExist() {
    PracticeContentCatalog.Question invalid = new PracticeContentCatalog.Question(
        "MATH-G3-TEST-001-Q01", 1, "SINGLE_CHOICE", "2 + 2 = ?",
        List.of(
            new PracticeContentCatalog.Option("A", "3"),
            new PracticeContentCatalog.Option("B", "4")),
        "Z", "选择正确结果。", List.of("计算 2 + 2。"), List.of("计算"));

    List<PracticeContentCatalog.Question> questions = new ArrayList<>();
    questions.add(invalid);
    for (int i = 2; i <= 5; i++) {
      questions.add(new PracticeContentCatalog.Question(
          "MATH-G3-TEST-001-Q0" + i, i, "NUMBER", i + " + 1 = ?",
          List.of(), Integer.toString(i + 1), "直接计算。", List.of("先做加法。"), List.of("计算")));
    }

    PracticeContentCatalog.Paper paper = new PracticeContentCatalog.Paper(
        "MATH-G3-TEST-001", 1, "G3", "MATH", "测试卷", "验证答案约束",
        "L1", 5, 10, List.of("测试"), "AI_GENERATED", "PUBLISHED", questions);

    assertThrows(IllegalStateException.class, () -> validator.validatePaper(paper));
  }
}
