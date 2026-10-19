package com.xiaoban.homework.organizer;

import java.util.LinkedHashSet;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Homework ownership is student + subject, not an independently maintained teacher directory.
 * A named teacher is an OPTIONAL finer-grained scope only when a source explicitly identifies
 * one unique person. Otherwise retain an honest subject scope, never invent a teacher's name.
 */
final class HomeworkTeacherAttribution {
  static final String SUBJECT_PREFIX = "学科归属:";
  private static final Pattern NAMED_TEACHER = Pattern.compile(
      "(?:^|[\\s:：，,；;【（(])([\\p{IsHan}]{1,3}老师)(?=[:：\\s，,；;。】）)]|$)");
  private static final Set<String> GENERIC = Set.of(
      "语文老师", "数学老师", "英语老师", "体育老师", "音乐老师", "美术老师",
      "科学老师", "班主任老师", "任课老师", "代课老师");

  private HomeworkTeacherAttribution() {}

  static String subjectScope(String subject) {
    return SUBJECT_PREFIX + safe(subject);
  }

  static boolean isSubjectScope(String name) {
    return safe(name).startsWith(SUBJECT_PREFIX);
  }

  static String resolve(String existing, String subject, String sourceLabel, String excerpt) {
    String specified = safe(existing);
    if (!specified.isBlank() && !specified.equals("未知") && !specified.equals("未识别"))
      return specified; // Backward compatibility for confirmed legacy attribution.
    String inferred = explicitSourceTeacher(safe(sourceLabel) + "\n" + safe(excerpt));
    return inferred.isEmpty() ? subjectScope(subject) : inferred;
  }

  static boolean hasNamedTeachers(String text) {
    var matcher = NAMED_TEACHER.matcher(safe(text));
    while (matcher.find()) {
      if (!GENERIC.contains(matcher.group(1))) return true;
    }
    return false;
  }

  static String explicitSourceTeacher(String text) {
    var found = new LinkedHashSet<String>();
    var matcher = NAMED_TEACHER.matcher(safe(text));
    while (matcher.find()) {
      String name = matcher.group(1);
      if (!GENERIC.contains(name)) found.add(name);
      if (found.size() > 1) return "";
    }
    return found.size() == 1 ? found.iterator().next() : "";
  }

  /**
   * A subject-scoped rule is only safe for a single clearly identified subject.
   * Mixed-subject notices cannot attribute the cue to a teacher before parsing.
   */
  static boolean matchesUnambiguousSubject(String source, String subject) {
    if (!safe(source).contains(safe(subject))) return false;
    int count = 0;
    for (String schoolSubject : Set.of("语文", "数学", "英语")) {
      if (safe(source).contains(schoolSubject)) count++;
    }
    return count <= 1;
  }

  private static String safe(String value) { return value == null ? "" : value.trim(); }
}
