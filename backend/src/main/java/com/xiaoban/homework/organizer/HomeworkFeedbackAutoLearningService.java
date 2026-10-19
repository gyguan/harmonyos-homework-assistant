package com.xiaoban.homework.organizer;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;

/**
 * Converts a parent's explicit error report into narrowly scoped, reversible
 * contextual experience. No AI-generated text is promoted as a global rule.
 * Evidence-free feedback remains recorded for review rather than becoming a guess.
 */
@Service
public class HomeworkFeedbackAutoLearningService {
  private static final int MAX_RECORDS = 80;
  private static final Set<String> LEARNABLE = Set.of(
      "SHORTHAND", "WRONG_CONTENT", "WRONG_SPLIT", "OMISSION", "WRONG_SUBJECT",
      "WRONG_DATE", "DUPLICATE", "OTHER");
  private static final Pattern ABBREVIATION =
      Pattern.compile("(?<![\\p{L}\\p{N}])([\\p{IsHan}]{1,3}|[A-Za-z]{1,5})([0-9]{1,3})(?![0-9])");

  private final HomeworkTeacherExperienceRepository experiences;
  private final HomeworkOrganizerAiSnapshotRepository snapshots;

  public HomeworkFeedbackAutoLearningService(HomeworkTeacherExperienceRepository experiences,
      HomeworkOrganizerAiSnapshotRepository snapshots) {
    this.experiences = experiences;
    this.snapshots = snapshots;
  }

  /**
   * Runs inside the caller's feedback transaction. Returns APPLIED only after
   * an actual active rule is persisted. Never re-enables a disabled rule silently.
   */
  String evaluate(HomeworkOrganizerFeedbackEntity record) {
    if (!LEARNABLE.contains(record.feedbackTypeCode) ||
        record.batchId == null || record.batchId.isBlank() ||
        record.candidateId == null || record.candidateId.isBlank()) {
      return "PENDING_EVIDENCE";
    }
    List<HomeworkOrganizerAiSnapshotEntity> batch = snapshots
        .findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
            record.familyId, record.studentId, record.batchId);
    var source = batch.stream()
        .filter(item -> record.candidateId.equals(item.candidateId)).findFirst().orElse(null);
    if (source == null) return "PENDING_EVIDENCE";

    String excerpt = clean(source.sourceExcerpt);
    // Reject spoofed/mixed-batch source excerpts; a model summary is not a trusted
    // full transcript, so we learn only narrow cues and never mutate global rules.
    if (excerpt.length() < 6 || !excerpt.equals(clean(record.sourceExcerpt)) ||
        excerpt.equals(clean(source.title))) return "PENDING_EVIDENCE";

    String details = clean(record.details);
    String after = clean(record.currentTitle);
    String before = clean(source.title);
    String requestedSubject = clean(record.subject);
    boolean correctedTitle = !after.isBlank() && !after.equals(before);
    boolean correctedSubject = !requestedSubject.isBlank()
        && !requestedSubject.equals(clean(source.subject));
    if (details.length() < 6 && !correctedTitle && !correctedSubject) {
      return "PENDING_EVIDENCE";
    }
    if ("SHORTHAND".equals(record.feedbackTypeCode) && details.length() < 6) {
      return "PENDING_EVIDENCE";
    }
    if ("WRONG_SUBJECT".equals(record.feedbackTypeCode) &&
        !correctedSubject && details.length() < 6) return "PENDING_EVIDENCE";

    String cue = autoCue(record.feedbackTypeCode, excerpt);
    if (!HomeworkExperienceCueMatcher.valid(cue) ||
        !HomeworkExperienceCueMatcher.matches(cue, excerpt)) return "PENDING_EVIDENCE";

    String teacher = clean(record.teacherName);
    // Historical snapshots might store an empty teacher field. A subject marker
    // is a scope, not a fabricated teacher's identity.
    if (teacher.isBlank() || "未知".equals(teacher) || "未识别".equals(teacher)) {
      teacher = HomeworkTeacherAttribution.subjectScope(clean(source.subject));
    }
    String subject = clean(source.subject);
    if (subject.isBlank()) return "PENDING_EVIDENCE";
    String interpretation = interpretation(record.feedbackTypeCode, details,
        before, correctedTitle ? after : "", correctedSubject ? requestedSubject : "");
    if (interpretation.length() < 6) return "PENDING_EVIDENCE";
    List<HomeworkTeacherExperienceEntity> existing = experiences
        .findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(record.familyId, record.studentId);
    if (experiences.findBySourceFeedbackId(record.id).isPresent()) {
      // A duplicate/retried request must not overwrite or re-enable a rule.
      return "APPLIED";
    }
    boolean collision = existing.stream().anyMatch(item ->
        item.active && teacher.equals(item.teacherName) && subject.equals(item.subject)
        && cue.equals(item.cue) && !interpretation.equals(item.interpretation));
    if (collision || existing.size() >= MAX_RECORDS) return "REVIEW_REQUIRED";

    var rule = new HomeworkTeacherExperienceEntity();
    rule.id = UUID.randomUUID();
    rule.familyId = record.familyId;
    rule.studentId = record.studentId;
    rule.teacherName = teacher;
    rule.subject = subject;
    rule.cue = cue;
    rule.interpretation = interpretation.substring(0, Math.min(600, interpretation.length()));
    rule.exampleSource = excerpt.substring(0, Math.min(400, excerpt.length()));
    rule.exampleResult = correctedTitle ? after.substring(0, Math.min(400, after.length())) : "";
    rule.sourceFeedbackId = record.id;
    rule.origin = "FEEDBACK_AUTO";
    rule.active = true;
    rule.createdAt = Instant.now();
    rule.updatedAt = rule.createdAt;
    experiences.save(rule);
    return "APPLIED";
  }

  static String autoCue(String category, String excerpt) {
    // Generalize only an unambiguous, compact abbreviation from a parent's
    // shorthand correction. Ordinary text/date/page numbers remain exact-match.
    if ("SHORTHAND".equals(category)) {
      Matcher matcher = ABBREVIATION.matcher(excerpt);
      String only = "";
      while (matcher.find()) {
        String prefix = matcher.group(1);
        if (prefix.equals("第") || prefix.equals("页") || prefix.equals("题") ||
            prefix.equals("月") || prefix.equals("日") || prefix.equals("P")) continue;
        String candidate = prefix + "*";
        if (!only.isEmpty() && !only.equals(candidate)) {
          only = "";
          break;
        }
        only = candidate;
      }
      if (!only.isEmpty()) return only;
    }
    // The full text of a single original assignment is the conservative key:
    // page numbers, dates and task-specific details must not leak to other work.
    return excerpt.length() <= 120 ? excerpt : excerpt.substring(0, 120);
  }

  private static String interpretation(String type, String details, String before,
      String after, String correctedSubject) {
    StringBuilder b = new StringBuilder("家长在这份原文上反馈「").append(type).append("」。");
    if (!details.isBlank()) b.append("家长指出：").append(shortText(details, 240)).append("。");
    if (!after.isBlank()) b.append("已纠正标题示例：").append(shortText(after, 150)).append("。");
    if (!correctedSubject.isBlank()) {
      b.append("本例家长更正为科目「").append(shortText(correctedSubject, 20)).append("」。");
    }
    b.append("仅当原文证据支持时参考，不照搬本例的页码、日期、题号或推测任务；")
        .append("优先逐项核对，不能省略或虚构作业。");
    return b.toString();
  }

  private static String shortText(String s, int max) {
    String safe = clean(s).replaceAll("[\\r\\n\\t]+", " ").replace('「', ' ').replace('」', ' ');
    return safe.substring(0, Math.min(max, safe.length()));
  }
  private static String clean(String value) { return value == null ? "" : value.trim(); }
}
