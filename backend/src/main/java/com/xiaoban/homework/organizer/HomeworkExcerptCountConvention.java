package com.xiaoban.homework.organizer;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Deterministic syntax for "摘抄：（N+M）". Its meaning is NOT a global default:
 * it can be applied only when this student has an active, explicitly confirmed
 * experience mapping the first number to 好词 and the second number to 好句.
 */
final class HomeworkExcerptCountConvention {
  static final String CONFIRMED_MEANING =
      "摘抄双数字约定：前面的数字为好词数量，后面的数字为好句数量；必须按本次原文实际数字展开。";

  private static final Pattern COUNTS = Pattern.compile(
      "摘抄\\s*[：:]?\\s*[（(]\\s*([0-9]{1,2})\\s*[+＋]\\s*([0-9]{1,2})\\s*[）)]");
  private static final Pattern SUBJECT = Pattern.compile("^(语文|阅读|其他)$");

  record Pair(int words, int sentences) {
    String title() {
      return "摘抄" + words + "个好词、" + sentences + "个好句";
    }

    String amount() {
      return words + "个好词、" + sentences + "个好句";
    }
  }

  private HomeworkExcerptCountConvention() {}

  static Pair extract(String text) {
    if (text == null || text.isBlank()) return null;
    Matcher match = COUNTS.matcher(text);
    if (!match.find()) return null;
    Pair found = new Pair(Integer.parseInt(match.group(1)), Integer.parseInt(match.group(2)));
    // If several different counts appear in a single excerpt, never guess
    // which pair applies; require a separately attributed candidate excerpt.
    while (match.find()) {
      Pair next = new Pair(Integer.parseInt(match.group(1)), Integer.parseInt(match.group(2)));
      if (!found.equals(next)) return null;
    }
    return found;
  }

  static boolean mentionsPair(String source, Pair wanted) {
    if (source == null || wanted == null) return false;
    Matcher match = COUNTS.matcher(source);
    while (match.find()) {
      if (wanted.words() == Integer.parseInt(match.group(1))
          && wanted.sentences() == Integer.parseInt(match.group(2))) return true;
    }
    return false;
  }

  /** Parent must explicitly state BOTH directions, not just "好词好句". */
  static boolean confirmedMeaning(String excerpt, String explanation) {
    Pair pair = extract(excerpt);
    if (pair == null || explanation == null) return false;
    String words = Integer.toString(pair.words());
    String sentences = Integer.toString(pair.sentences());
    String numericExplanation = Pattern.quote(words)
        + "\\s*(?:个|条)?\\s*好词[\\s\\S]{0,35}"
        + Pattern.quote(sentences) + "\\s*(?:个|条)?\\s*好句";
    boolean explicit = Pattern.compile(numericExplanation).matcher(explanation).find();
    boolean ordered = explanation.matches(
        "(?s).*前(?:一个|面|项|数|数字).{0,24}好词.{0,48}后(?:一个|面|项|数|数字).{0,24}好句.*");
    return explicit || ordered;
  }

  static boolean isConfirmed(HomeworkTeacherExperienceEntity row) {
    if (row == null || !row.active || row.subject == null
        || !SUBJECT.matcher(row.subject).matches()
        || row.interpretation == null) return false;
    return (row.interpretation.contains(CONFIRMED_MEANING)
        || confirmedMeaning(row.exampleSource, row.interpretation))
        && extract(row.exampleSource) != null;
  }

  static String learnedCue(String excerpt, String details) {
    return confirmedMeaning(excerpt, details) ? "摘抄" : "";
  }

  static HomeworkOrganizerDtos.Candidate rewrite(HomeworkOrganizerDtos.Candidate candidate,
      Pair counts) {
    if (candidate == null || counts == null || candidate.title() == null
        || !candidate.title().contains("摘抄")) return candidate;
    String oldTitle = candidate.title();
    String title = expand(oldTitle, counts);
    String instruction = candidate.instruction() == null ? "" : candidate.instruction();
    String newInstruction = expand(instruction, counts);
    if (!newInstruction.contains(counts.amount())) {
      newInstruction = (newInstruction.isBlank() ? "" : newInstruction + "；") + counts.title();
    }
    // Other task fields, especially the original source excerpt, remain intact.
    return new HomeworkOrganizerDtos.Candidate(
        candidate.subject(), limit(title, 300), limit(newInstruction, 1500),
        candidate.textbookRef(), candidate.taskDate(), candidate.expectedMinutes(),
        candidate.sourceExcerpt(), candidate.confidence(), candidate.sameTaskGroup(),
        candidate.duplicateAssignmentId(), candidate.duplicateAssignmentTitle(),
        candidate.duplicateConfidence(), candidate.duplicateReason());
  }

  private static String expand(String value, Pair counts) {
    Matcher match = COUNTS.matcher(value);
    if (match.find()) {
      Pair fromText = new Pair(Integer.parseInt(match.group(1)), Integer.parseInt(match.group(2)));
      if (counts.equals(fromText)) return match.replaceFirst(counts.title());
    }
    if (value.contains("摘抄") && !value.contains("好词") && !value.contains("好句")) {
      return value + "（" + counts.amount() + "）";
    }
    return value;
  }

  private static String limit(String value, int maximum) {
    return value.length() <= maximum ? value : value.substring(0, maximum);
  }
}
