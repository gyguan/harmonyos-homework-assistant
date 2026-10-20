package com.xiaoban.homework.organizer;

import java.text.Normalizer;
import java.util.Locale;

/** Generic lexical ranking; numeric erasure matches patterns, never interprets their meaning. */
final class HomeworkExperienceRetrieval {
  private HomeworkExperienceRetrieval() {}
  static String lexical(String value) {
    return Normalizer.normalize(value == null ? "" : value, Normalizer.Form.NFKC)
        .toLowerCase(Locale.ROOT).replaceAll("[\\p{N}\\p{P}\\p{Z}\\s*]+", "");
  }
  static double score(HomeworkTeacherExperienceEntity entry, String source) {
    if (HomeworkExperienceCueMatcher.matches(entry.cue, source)) return 100;
    // Unconfirmed literal edits are not generalized into reusable rules.
    if (!java.util.List.of("FEEDBACK_AI", "FEEDBACK_AUTO").contains(String.valueOf(entry.origin))) return 0;
    String cue = lexical(entry.cue);
    String text = lexical(source);
    if (cue.length() >= 2 && text.contains(cue)) return 80;
    return 0;
  }
}
