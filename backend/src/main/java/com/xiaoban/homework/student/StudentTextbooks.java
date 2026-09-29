package com.xiaoban.homework.student;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public record StudentTextbooks(
    String chinese,
    String math,
    String english,
    String others) {

  public StudentTextbooks {
    chinese = clean(chinese);
    math = clean(math);
    english = clean(english);
    others = clean(others);
  }

  public static StudentTextbooks from(StudentEntity entity) {
    StudentTextbooks structured = new StudentTextbooks(
        entity.chineseTextbook,
        entity.mathTextbook,
        entity.englishTextbook,
        entity.otherTextbooks);
    if (!structured.isEmpty()) return structured;
    return parseLegacy(entity.textbookSummary);
  }

  public static StudentTextbooks from(StudentDtos.Upsert input) {
    StudentTextbooks structured = new StudentTextbooks(
        input.chineseTextbook(),
        input.mathTextbook(),
        input.englishTextbook(),
        input.otherTextbooks());
    if (!structured.isEmpty()) return structured;
    return parseLegacy(input.textbookSummary());
  }

  public String forSubject(String subject) {
    String normalized = subject == null ? "" : subject.trim().toUpperCase(Locale.ROOT);
    if ("CHINESE".equals(normalized)) return chinese;
    if ("MATH".equals(normalized)) return math;
    if ("ENGLISH".equals(normalized)) return english;
    return "";
  }

  public boolean isEmpty() {
    return chinese.isBlank() && math.isBlank() && english.isBlank() && others.isBlank();
  }

  public String summary() {
    List<String> parts = new ArrayList<>();
    if (!chinese.isBlank()) parts.add("语文=" + chinese);
    if (!math.isBlank()) parts.add("数学=" + math);
    if (!english.isBlank()) parts.add("英语=" + english);
    if (!others.isBlank()) parts.add(others);
    return String.join("；", parts);
  }

  static StudentTextbooks parseLegacy(String summary) {
    String text = clean(summary);
    if (text.isBlank()) return new StudentTextbooks("", "", "", "");

    String chinese = "";
    String math = "";
    String english = "";
    List<String> others = new ArrayList<>();
    String[] pieces = text
        .replace(" · ", "；")
        .replace("｜", "；")
        .replace("|", "；")
        .split("[；;\\r\\n]+");

    for (String piece : pieces) {
      String value = clean(piece);
      if (value.isBlank()) continue;
      if (value.startsWith("语文")) {
        chinese = cleanEdition(value, "语文");
      } else if (value.startsWith("数学")) {
        math = cleanEdition(value, "数学");
      } else if (value.startsWith("英语")) {
        english = cleanEdition(value, "英语");
      } else if (value.contains("语文") && !value.contains("数学") && !value.contains("英语")) {
        chinese = removeSubject(value, "语文");
      } else if (value.contains("数学") && !value.contains("语文") && !value.contains("英语")) {
        math = removeSubject(value, "数学");
      } else if (value.contains("英语") && !value.contains("语文") && !value.contains("数学")) {
        english = removeSubject(value, "英语");
      } else {
        others.add(value);
      }
    }
    return new StudentTextbooks(chinese, math, english, String.join("；", others));
  }

  private static String cleanEdition(String value, String subject) {
    String edition = value.substring(subject.length()).trim();
    while (edition.startsWith("=") || edition.startsWith("：") || edition.startsWith(":")) {
      edition = edition.substring(1).trim();
    }
    return edition;
  }

  private static String removeSubject(String value, String subject) {
    return clean(value.replace(subject, ""));
  }

  private static String clean(String value) {
    return value == null ? "" : value.trim();
  }
}
