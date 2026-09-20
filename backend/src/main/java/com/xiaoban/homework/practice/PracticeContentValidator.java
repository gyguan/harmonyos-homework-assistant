package com.xiaoban.homework.practice;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import org.springframework.stereotype.Component;

@Component
public class PracticeContentValidator {
  private static final Set<String> GRADES = Set.of("G1", "G2", "G3", "G4", "G5", "G6");
  private static final Set<String> SUBJECTS = Set.of("CHINESE", "MATH", "ENGLISH", "THINKING");
  private static final Set<String> DIFFICULTIES = Set.of("L1", "L2", "L3");
  private static final Set<String> SEMESTERS = Set.of("ALL", "S1", "S2");
  private static final Set<String> SOURCE_TYPES =
      Set.of("PRESET", "AI_GENERATED", "PARENT_CREATED", "IMPORTED");
  private static final Set<String> STATUSES = Set.of("PUBLISHED", "ARCHIVED");
  private static final Set<String> QUESTION_TYPES =
      Set.of("SINGLE_CHOICE", "MULTIPLE_CHOICE", "FILL_BLANK", "NUMBER", "SHORT_TEXT");
  private static final Set<String> VISUAL_TYPES =
      Set.of("NONE", "SCENE", "ARRAY", "DOT_ARRAY", "IMAGE_PAIR", "IMAGE_SEQUENCE",
          "DIALOGUE", "ROOM_SCENE", "FAMILY_SCENE", "CHARACTER", "ILLUSTRATION");

  public void validateCatalog(PracticeContentCatalog.Catalog catalog) {
    List<String> errors = new ArrayList<>();
    if (catalog == null) throw new IllegalStateException("练习内容 catalog 为空");
    if (catalog.schemaVersion() != 1) errors.add("schemaVersion 必须为 1");
    requireText(catalog.catalogId(), "catalogId", errors);
    if (catalog.papers() == null || catalog.papers().isEmpty()) errors.add("papers 不能为空");

    Set<String> paperKeys = new HashSet<>();
    Set<String> questionIds = new HashSet<>();
    if (catalog.papers() != null) {
      for (int i = 0; i < catalog.papers().size(); i++) {
        PracticeContentCatalog.Paper paper = catalog.papers().get(i);
        String path = "papers[" + i + "]";
        validatePaper(paper, path, errors, paperKeys, questionIds);
      }
    }
    if (!errors.isEmpty()) throw new IllegalStateException("练习内容校验失败:\n- " + String.join("\n- ", errors));
  }

  public void validatePaper(PracticeContentCatalog.Paper paper) {
    List<String> errors = new ArrayList<>();
    validatePaper(paper, "paper", errors, new HashSet<>(), new HashSet<>());
    if (!errors.isEmpty()) throw new IllegalStateException("练习套卷校验失败:\n- " + String.join("\n- ", errors));
  }

  private void validatePaper(PracticeContentCatalog.Paper paper, String path, List<String> errors,
      Set<String> paperKeys, Set<String> questionIds) {
    if (paper == null) {
      errors.add(path + " 不能为空");
      return;
    }
    requireText(paper.id(), path + ".id", errors);
    if (paper.version() < 1) errors.add(path + ".version 必须 >= 1");
    if (!GRADES.contains(paper.grade())) errors.add(path + ".grade 非法: " + paper.grade());
    if (!SUBJECTS.contains(paper.subject())) errors.add(path + ".subject 非法: " + paper.subject());
    if (!SEMESTERS.contains(paper.semester())) errors.add(path + ".semester 非法: " + paper.semester());
    if (!DIFFICULTIES.contains(paper.difficulty())) errors.add(path + ".difficulty 非法: " + paper.difficulty());
    if (!SOURCE_TYPES.contains(paper.sourceType())) errors.add(path + ".sourceType 非法: " + paper.sourceType());
    if (!STATUSES.contains(paper.status())) errors.add(path + ".status 非法: " + paper.status());
    requireText(paper.title(), path + ".title", errors);
    requireText(paper.description(), path + ".description", errors);
    if (paper.estimatedMinutes() < 1 || paper.estimatedMinutes() > 120) {
      errors.add(path + ".estimatedMinutes 必须在 1..120");
    }
    validateStringList(paper.tags(), path + ".tags", 1, 8, errors);

    String paperKey = paper.id() + "@" + paper.version();
    if (!paperKeys.add(paperKey)) errors.add(path + " paperId/version 重复: " + paperKey);
    if (paper.questions() == null || paper.questions().isEmpty()) {
      errors.add(path + ".questions 不能为空");
      return;
    }
    if (paper.questionCount() != paper.questions().size()) {
      errors.add(path + ".questionCount 与 questions 数量不一致");
    }
    if (paper.questionCount() < 5 || paper.questionCount() > 50) {
      errors.add(path + ".questionCount 必须在 5..50");
    }

    Set<Integer> orderNumbers = new HashSet<>();
    Set<String> stems = new HashSet<>();
    for (int i = 0; i < paper.questions().size(); i++) {
      PracticeContentCatalog.Question question = paper.questions().get(i);
      String qPath = path + ".questions[" + i + "]";
      validateQuestion(paper, question, qPath, errors, orderNumbers, stems, questionIds);
    }
    for (int expected = 1; expected <= paper.questions().size(); expected++) {
      if (!orderNumbers.contains(expected)) errors.add(path + " 题号不连续，缺少 orderNo=" + expected);
    }
  }

  private void validateQuestion(PracticeContentCatalog.Paper paper, PracticeContentCatalog.Question question,
      String path, List<String> errors, Set<Integer> orderNumbers, Set<String> stems, Set<String> questionIds) {
    if (question == null) {
      errors.add(path + " 不能为空");
      return;
    }
    requireText(question.id(), path + ".id", errors);
    if (question.id() != null && !question.id().startsWith(paper.id() + "-Q")) {
      errors.add(path + ".id 必须以 " + paper.id() + "-Q 开头");
    }
    if (question.id() != null && !questionIds.add(question.id())) {
      errors.add(path + ".id 全局重复: " + question.id());
    }
    if (question.orderNo() < 1 || !orderNumbers.add(question.orderNo())) {
      errors.add(path + ".orderNo 非法或重复: " + question.orderNo());
    }
    if (!QUESTION_TYPES.contains(question.type())) errors.add(path + ".type 非法: " + question.type());
    requireText(question.stem(), path + ".stem", errors);
    if (question.stem() != null && !stems.add(normalize(question.stem()))) {
      errors.add(path + ".stem 在同一套卷中重复");
    }
    requireText(question.answerSpec(), path + ".answerSpec", errors);
    requireText(question.explanation(), path + ".explanation", errors);
    validateStringList(question.hints(), path + ".hints", 1, 3, errors);
    validateStringList(question.tags(), path + ".tags", 1, 8, errors);
    validateVisualSpec(paper, question, path, errors);
    validateAnswerSpec(question, path, errors);
  }

  private void validateVisualSpec(PracticeContentCatalog.Paper paper,
      PracticeContentCatalog.Question question, String path, List<String> errors) {
    PracticeContentCatalog.VisualSpec visual = question.visualSpec();
    boolean p0 = paper.id() != null && paper.id().contains("-P0-");
    if (visual == null) {
      if (p0) errors.add(path + ".visualSpec P0 图文题不能为空");
      return;
    }
    if (!VISUAL_TYPES.contains(visual.type())) {
      errors.add(path + ".visualSpec.type 非法: " + visual.type());
    }
    if (p0 || !"NONE".equals(visual.type())) {
      requireText(visual.assetId(), path + ".visualSpec.assetId", errors);
      requireText(visual.layout(), path + ".visualSpec.layout", errors);
      requireText(visual.accessibilityText(), path + ".visualSpec.accessibilityText", errors);
    }
  }

  private void validateAnswerSpec(PracticeContentCatalog.Question question, String path, List<String> errors) {
    List<PracticeContentCatalog.Option> options =
        question.options() == null ? List.of() : question.options();
    if ("SINGLE_CHOICE".equals(question.type()) || "MULTIPLE_CHOICE".equals(question.type())) {
      if (options.size() < 2 || options.size() > 6) {
        errors.add(path + ".options 选择题必须有 2..6 个选项");
        return;
      }
      Set<String> keys = new HashSet<>();
      for (PracticeContentCatalog.Option option : options) {
        if (option == null || blank(option.key()) || blank(option.label())) {
          errors.add(path + ".options 包含空 key/label");
          continue;
        }
        String key = option.key().trim().toUpperCase(Locale.ROOT);
        if (!keys.add(key)) errors.add(path + ".options key 重复: " + key);
      }
      Set<String> expected = new HashSet<>();
      for (String item : question.answerSpec().split(",")) {
        String key = item.trim().toUpperCase(Locale.ROOT);
        if (!key.isEmpty()) expected.add(key);
      }
      if ("SINGLE_CHOICE".equals(question.type()) && expected.size() != 1) {
        errors.add(path + ".answerSpec 单选题只能有一个答案");
      }
      if (expected.isEmpty() || !keys.containsAll(expected)) {
        errors.add(path + ".answerSpec 必须引用已声明选项");
      }
    } else {
      if (!options.isEmpty()) errors.add(path + ".options 非选择题必须为空");
      if ("NUMBER".equals(question.type())) {
        try {
          new BigDecimal(question.answerSpec().trim());
        } catch (Exception e) {
          errors.add(path + ".answerSpec NUMBER 必须是可解析数字");
        }
      } else if (question.answerSpec().split("\\|").length == 0) {
        errors.add(path + ".answerSpec 文本题必须至少声明一个可接受答案");
      }
    }
  }

  private void validateStringList(List<String> values, String path, int min, int max, List<String> errors) {
    if (values == null || values.size() < min || values.size() > max) {
      errors.add(path + " 数量必须在 " + min + ".." + max);
      return;
    }
    Set<String> seen = new HashSet<>();
    for (String value : values) {
      if (blank(value)) errors.add(path + " 不能包含空值");
      else if (!seen.add(normalize(value))) errors.add(path + " 不能包含重复值: " + value);
    }
  }

  private void requireText(String value, String path, List<String> errors) {
    if (blank(value)) errors.add(path + " 不能为空");
  }

  private boolean blank(String value) {
    return value == null || value.trim().isEmpty();
  }

  private String normalize(String value) {
    return value == null ? "" : value.trim().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
  }
}
