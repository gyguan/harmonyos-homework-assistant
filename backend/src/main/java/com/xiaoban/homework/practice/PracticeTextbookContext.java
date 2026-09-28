package com.xiaoban.homework.practice;

import java.util.Locale;

final class PracticeTextbookContext {
  private PracticeTextbookContext() {}

  static String extract(String summary, String subject) {
    String text = summary == null ? "" : summary.trim();
    if (text.isBlank()) return "";

    String label = subjectLabel(subject);
    if (label.isBlank()) return text;

    String[] segments = text.split("[\\r\\n;；|,，]+");
    for (String segment : segments) {
      String value = segment.trim();
      if (value.contains(label) && subjectKindCount(value) == 1) return value;
    }

    // Legacy profiles often store only one subject in free text, such as
    // “人教版数学二年级上册”. Preserve that full context.
    if (subjectKindCount(text) <= 1) return text;

    String[] parts = text.split("(?=语文|数学|英语)");
    for (String part : parts) {
      String value = part.trim();
      if (value.startsWith(label)) return value;
    }
    return "";
  }

  static boolean compatible(String referenceContext, String targetSummary, String subject) {
    String reference = comparable(referenceContext, subject);
    String target = comparable(extract(targetSummary, subject), subject);
    return !reference.isBlank() && reference.equals(target);
  }

  static String comparable(String value, String subject) {
    String text = value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
    String label = subjectLabel(subject);
    if (!label.isBlank()) text = text.replace(label, "");
    return text.replaceAll("[\\s：:，,；;|/_\\-]+", "");
  }

  private static int subjectKindCount(String value) {
    int count = 0;
    if (value.contains("语文")) count++;
    if (value.contains("数学")) count++;
    if (value.contains("英语")) count++;
    return count;
  }

  private static String subjectLabel(String subject) {
    if ("CHINESE".equalsIgnoreCase(subject)) return "语文";
    if ("MATH".equalsIgnoreCase(subject)) return "数学";
    if ("ENGLISH".equalsIgnoreCase(subject)) return "英语";
    return "";
  }
}
