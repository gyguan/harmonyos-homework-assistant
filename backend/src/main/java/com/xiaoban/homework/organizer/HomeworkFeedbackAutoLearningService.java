package com.xiaoban.homework.organizer;

import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * Feedback -> verified source -> AI generalization -> scoped reusable experience.
 * Java never encodes an individual teacher's abbreviation or correction rule.
 */
@Service
public class HomeworkFeedbackAutoLearningService {
  private static final int MAX_RECORDS = 80;
  private static final Set<String> LEARNABLE = Set.of(
      "SHORTHAND", "WRONG_CONTENT", "WRONG_SPLIT", "OMISSION", "WRONG_SUBJECT",
      "WRONG_DATE", "DUPLICATE", "OTHER");

  private final HomeworkTeacherExperienceRepository experiences;
  private final HomeworkOrganizerAiSnapshotRepository snapshots;
  private final HomeworkFeedbackExperienceModel model;

  // Backwards compatible with tests that only inspect evidence validation.
  public HomeworkFeedbackAutoLearningService(HomeworkTeacherExperienceRepository experiences,
      HomeworkOrganizerAiSnapshotRepository snapshots) {
    this(experiences, snapshots, null);
  }

  @Autowired
  public HomeworkFeedbackAutoLearningService(HomeworkTeacherExperienceRepository experiences,
      HomeworkOrganizerAiSnapshotRepository snapshots, HomeworkFeedbackExperienceModel model) {
    this.experiences = experiences;
    this.snapshots = snapshots;
    this.model = model;
  }

  /**
   * Returns APPLIED only for a persisted experience; PENDING_AI when the model
   * was unavailable/returned no readable result; never declares a save as learned.
   * The calling feedback service persists both records in one transaction.
   */
  String evaluate(HomeworkOrganizerFeedbackEntity record) {
    if (!LEARNABLE.contains(record.feedbackTypeCode)
        || blank(record.batchId) || blank(record.candidateId)) return "PENDING_EVIDENCE";

    var original = snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        record.familyId, record.studentId, record.batchId).stream()
        .filter(row -> Objects.equals(record.candidateId, row.candidateId))
        .findFirst().orElse(null);
    if (original == null || blank(original.subject) || blank(original.sourceExcerpt)
        || !clean(original.sourceExcerpt).equals(clean(record.sourceExcerpt))
        || (blank(record.details)
            && Objects.equals(clean(original.title), clean(record.currentTitle)))) {
      return "PENDING_EVIDENCE";
    }

    if (experiences.findBySourceFeedbackId(record.id).isPresent()) return "APPLIED";
    if (model == null || !model.available()) return "PENDING_AI";

    var extracted = model.extract(record, original);
    if (extracted.isEmpty()) return "PENDING_AI";
    var result = extracted.get();
    if (!result.reusable() || result.confidence() < 0.78) return "PENDING_EVIDENCE";

    String cue = clean(result.cue());
    String conditions = clean(result.applyWhen());
    String guidance = clean(result.guidance());
    if (!HomeworkExperienceCueMatcher.valid(cue) || cue.contains("*")
        || cue.contains("|") || cue.equals("老师") || cue.equals("作业")
        || cue.equals("任务") || conditions.length() < 8
        || guidance.length() < 12 || conditions.length() > 240
        || guidance.length() > 330 || !Double.isFinite(result.confidence())) {
      return "REVIEW_REQUIRED";
    }

    // Experience text is untrusted data passed to later models under explicit
    // instruction hierarchy. Keep only short declarative conditions/guidance.
    String interpreted = "适用条件：" + oneLine(conditions) +
        "；整理要求：" + oneLine(guidance);
    String teacher = clean(original.teacherName);
    if (teacher.isEmpty() || "未知".equals(teacher) || "未识别".equals(teacher)) {
      teacher = HomeworkTeacherAttribution.subjectScope(original.subject);
    }
    final String boundTeacher = teacher;
    String subject = original.subject;
    List<HomeworkTeacherExperienceEntity> saved =
        experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(record.familyId, record.studentId);

    var duplicate = saved.stream().filter(row -> row.active
        && Objects.equals(boundTeacher, row.teacherName)
        && Objects.equals(subject, row.subject)
        && Objects.equals(cue, row.cue)
        && Objects.equals(interpreted, row.interpretation)).findFirst();
    if (duplicate.isPresent()) return "APPLIED";

    boolean collision = saved.stream().anyMatch(row -> row.active
        && Objects.equals(boundTeacher, row.teacherName)
        && Objects.equals(subject, row.subject) && Objects.equals(cue, row.cue)
        && !Objects.equals(interpreted, row.interpretation));
    if (collision || saved.size() >= MAX_RECORDS) return "REVIEW_REQUIRED";

    var experience = new HomeworkTeacherExperienceEntity();
    experience.id = UUID.randomUUID();
    experience.familyId = record.familyId;
    experience.studentId = record.studentId;
    experience.teacherName = teacher;
    experience.subject = subject;
    experience.cue = cue;
    experience.interpretation = interpreted;
    experience.exampleSource = limit(clean(original.sourceExcerpt), 400);
    String edited = clean(record.currentTitle);
    experience.exampleResult = edited.equals(clean(original.title)) ? "" : limit(edited, 400);
    experience.origin = "FEEDBACK_AI";
    experience.active = true;
    experience.sourceFeedbackId = record.id;
    experience.createdAt = Instant.now();
    experience.updatedAt = experience.createdAt;
    experiences.save(experience);
    return "APPLIED";
  }

  private static String limit(String input, int max) {
    return input.length() > max ? input.substring(0, max) : input;
  }
  private static boolean blank(String value) { return value == null || value.isBlank(); }
  private static String clean(String value) { return value == null ? "" : value.trim(); }
  private static String oneLine(String value) {
    return clean(value).replaceAll("[\\r\\n\\t]+", " ");
  }
}
