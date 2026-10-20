package com.xiaoban.homework.organizer;

import com.xiaoban.homework.student.StudentEntity;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * DB is the only production source for global glossary and source-template experiences.
 * The same immutable snapshot is used for AI instructions and deterministic postprocessing.
 * A disabled DB row is never restored from Java constants or environment variables.
 */
@Service
public class HomeworkOrganizerRuleService {
  private final HomeworkOrganizerRuleRepository repository;

  public HomeworkOrganizerRuleService(HomeworkOrganizerRuleRepository repository) {
    this.repository = repository;
  }

  public record Snapshot(List<String> shorthand, Map<String, String> templates, String version) {
    public Snapshot(List<String> shorthand, Map<String, String> templates) {
      this(shorthand, templates, HomeworkOrganizerTelemetry.fingerprint(shorthand + ":" + new java.util.TreeMap<>(templates)));
    }
    public Snapshot {
      shorthand = List.copyOf(shorthand);
      templates = Map.copyOf(templates);
    }
    public String template(String key) { return templates.getOrDefault(key, ""); }
    public String encodedShorthand() {
      // Runtime DB entries use the record separator, not the legacy env's semicolon:
      // descriptions often contain natural-language Chinese semicolons.
      String delimiter = Character.toString((char) 0x1e);
      return shorthand.isEmpty() ? "" : delimiter + String.join(delimiter, shorthand);
    }
  }

  @Transactional(readOnly = true)
  public Snapshot snapshot(StudentEntity student, String sourceLabel, String sourceText) {
    var shorthands = new LinkedHashMap<String, String>();
    var templates = new LinkedHashMap<String, String>();
    var versions = new ArrayList<String>();
    for (var rule : repository.findApplicable(
        student == null ? null : student.familyId,
        student == null ? null : student.id)) {
      if (!applicable(rule, student, sourceLabel, sourceText)) continue;
      versions.add(rule.code + ":" + rule.version + ":" + rule.updatedAt);
      if ("SHORTHAND".equals(rule.ruleType)) {
        String term = safe(rule.triggerText);
        String subject = safe(rule.subject);
        String meaning = safe(rule.meaning);
        if (subject.isEmpty() || term.isEmpty() || meaning.isEmpty()) continue;
        if (subject.contains("|") || term.contains("|") || meaning.contains("|")) continue;
        String title = safe(rule.shortTitle);
        if (title.contains("|") || subject.contains("\n") || term.contains("\n")) continue;
        shorthands.putIfAbsent(subject + "\u001f" + term,
            String.join("|", subject, term, meaning, title));
      } else if ("PROMPT".equals(rule.ruleType)) {
        String kind = safe(rule.templateKey);
        if (List.of("THREE_PART", "ENGLISH", "BLACKBOARD").contains(kind)) {
          templates.putIfAbsent(kind, safe(rule.promptText));
        }
      }
    }
    return new Snapshot(new ArrayList<>(shorthands.values()), templates,
        HomeworkOrganizerTelemetry.fingerprint(String.join("\n", versions)));
  }

  private boolean applicable(HomeworkOrganizerRuleEntity rule, StudentEntity student,
      String sourceLabel, String sourceText) {
    if ("GLOBAL".equals(rule.scope)) return true;
    if (student == null || student.id == null || student.familyId == null ||
        !Objects.equals(rule.familyId, student.familyId) ||
        !Objects.equals(rule.studentId, student.id)) return false;
    String source = safe(sourceLabel) + "\n" + safe(sourceText);
    // For a student-specific rule, require an unambiguous named subject in the
    // source. Image content without a reliable source text never guesses attribution.
    if (!safe(rule.subject).isBlank() &&
        !HomeworkTeacherAttribution.matchesUnambiguousSubject(source, rule.subject)) return false;
    if ("STUDENT".equals(rule.scope)) {
      return !HomeworkTeacherAttribution.hasNamedTeachers(source);
    }
    if ("TEACHER".equals(rule.scope)) {
      return !safe(rule.teacherName).isEmpty() &&
          safe(rule.teacherName).equals(HomeworkTeacherAttribution.explicitSourceTeacher(source));
    }
    return false;
  }

  private static String safe(String value) { return value == null ? "" : value.trim(); }
}
