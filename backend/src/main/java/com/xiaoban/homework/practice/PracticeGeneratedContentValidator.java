package com.xiaoban.homework.practice;

import java.math.BigDecimal;
import java.math.MathContext;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public class PracticeGeneratedContentValidator {
  private static final Set<String> SUBJECTS = Set.of("CHINESE", "MATH", "ENGLISH");
  private static final Set<String> TYPES = Set.of("SINGLE_CHOICE", "FILL_BLANK", "NUMBER");
  private static final Pattern CHINESE_CHAR = Pattern.compile(".*[\\u4e00-\\u9fff].*");
  private static final Pattern SIMPLE_ARITHMETIC = Pattern.compile(
      "(?<!\\d)(-?\\d+(?:\\.\\d+)?)\\s*([+\\-×xX*÷/])\\s*(-?\\d+(?:\\.\\d+)?)(?!\\d)");
  private static final String[] VISUAL_DEPENDENCY = {
      "看图", "图中", "图片", "如图", "上图", "下图", "画面"
  };

  private final PracticeContentValidator base;

  public PracticeGeneratedContentValidator(PracticeContentValidator base) {
    this.base = base;
  }

  public void validate(PracticeContentCatalog.Paper paper, int expectedQuestionCount) {
    base.validatePaper(paper);
    if (!"AI_GENERATED".equals(paper.sourceType())) {
      throw new IllegalStateException("AI生成套卷 sourceType 必须为 AI_GENERATED");
    }
    if (!SUBJECTS.contains(paper.subject())) {
      throw new IllegalStateException("AI生成暂只支持语文、数学、英语");
    }
    if (paper.questionCount() != expectedQuestionCount) {
      throw new IllegalStateException("AI生成题量与家长要求不一致");
    }

    Set<String> normalizedStems = new HashSet<>();
    for (PracticeContentCatalog.Question question : paper.questions()) {
      if (!TYPES.contains(question.type())) {
        throw new IllegalStateException("AI生成包含暂不支持题型: " + question.type());
      }
      String stem = text(question.stem());
      for (String token : VISUAL_DEPENDENCY) {
        if (stem.contains(token)) {
          throw new IllegalStateException("题目依赖当前不支持的视觉材料: " + token);
        }
      }
      if (!normalizedStems.add(stem.replaceAll("\\s+", "").toLowerCase(Locale.ROOT))) {
        throw new IllegalStateException("AI生成存在重复题目");
      }
      if ("ENGLISH".equals(paper.subject()) && !CHINESE_CHAR.matcher(stem).matches()) {
        throw new IllegalStateException("英语题干必须包含中文操作说明");
      }
      if (question.hints() == null || question.hints().size() != 1
          || !text(question.hints().get(0)).startsWith("关键词：")) {
        throw new IllegalStateException("每题必须提供一条以“关键词：”开头的提示");
      }
      if ("MATH".equals(paper.subject()) && "NUMBER".equals(question.type())) {
        verifySimpleArithmetic(question);
      }
      if ("SINGLE_CHOICE".equals(question.type())) {
        if (question.options() == null || question.options().size() < 3 || question.options().size() > 4) {
          throw new IllegalStateException("AI单选题必须有3到4个选项");
        }
        Set<String> labels = new HashSet<>();
        for (PracticeContentCatalog.Option option : question.options()) {
          if (!labels.add(text(option.label()).replaceAll("\\s+", "").toLowerCase(Locale.ROOT))) {
            throw new IllegalStateException("AI单选题选项文本不能重复");
          }
        }
      } else if (question.options() != null && !question.options().isEmpty()) {
        throw new IllegalStateException("非选择题不能携带选项");
      }
    }
  }

  private static void verifySimpleArithmetic(PracticeContentCatalog.Question question) {
    java.util.regex.Matcher matcher = SIMPLE_ARITHMETIC.matcher(text(question.stem()));
    if (!matcher.find()) return;

    try {
      BigDecimal left = new BigDecimal(matcher.group(1));
      BigDecimal right = new BigDecimal(matcher.group(3));
      BigDecimal expected = switch (matcher.group(2)) {
        case "+" -> left.add(right);
        case "-" -> left.subtract(right);
        case "×", "x", "X", "*" -> left.multiply(right);
        case "÷", "/" -> {
          if (BigDecimal.ZERO.compareTo(right) == 0) {
            throw new IllegalStateException("数学题包含除以0");
          }
          yield left.divide(right, MathContext.DECIMAL64);
        }
        default -> throw new IllegalStateException("不支持的算术运算符");
      };
      BigDecimal actual = new BigDecimal(text(question.answerSpec()));
      if (expected.compareTo(actual) != 0) {
        throw new IllegalStateException(
            "数学题答案校验失败: " + question.id() + "，期望=" +
                expected.stripTrailingZeros().toPlainString() + "，实际=" +
                actual.stripTrailingZeros().toPlainString());
      }
    } catch (NumberFormatException error) {
      throw new IllegalStateException("数学题答案不是有效数字: " + question.id(), error);
    }
  }

  private static String text(String value) {
    return value == null ? "" : value.trim();
  }
}
