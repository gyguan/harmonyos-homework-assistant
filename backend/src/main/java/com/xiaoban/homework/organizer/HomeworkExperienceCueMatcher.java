package com.xiaoban.homework.organizer;

import java.util.regex.Pattern;

/** Literal teacher vocabulary cues, with one optional '*' meaning a 1–3 digit number. */
final class HomeworkExperienceCueMatcher {
  private HomeworkExperienceCueMatcher() {}

  static boolean valid(String cue) {
    if (cue == null || cue.length() < 2 || cue.length() > 120 || cue.isBlank()
        || cue.contains("\n") || cue.contains("\r")) return false;
    int star = cue.indexOf('*');
    if (star < 0) return true;
    return star > 0 && star == cue.lastIndexOf('*')
        && cue.replace("*", "").trim().length() >= 1;
  }

  static boolean matches(String cue, String source) {
    if (!valid(cue) || source == null || source.isBlank()) return false;
    int star = cue.indexOf('*');
    if (star < 0) return source.contains(cue);
    String regex = Pattern.quote(cue.substring(0, star))
        + "[0-9]{1,3}" + Pattern.quote(cue.substring(star + 1));
    return Pattern.compile(regex).matcher(source).find();
  }
}
