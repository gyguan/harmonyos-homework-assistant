package com.xiaoban.homework.organizer;

import com.xiaoban.homework.ai.AiProviderProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * One-time bridge for already deployed AI_HOMEWORK_SHORTHAND configuration.
 * The dynamic runtime NEVER reads environment rules: edits, deletes and disabling
 * are fully governed by DB after the first successful import. No reactivation.
 */
@Component
public class HomeworkOrganizerLegacyShorthandImport implements ApplicationRunner {
  private final AiProviderProperties properties;
  private final HomeworkOrganizerRuleRepository repository;

  public HomeworkOrganizerLegacyShorthandImport(AiProviderProperties properties,
      HomeworkOrganizerRuleRepository repository) {
    this.properties = properties;
    this.repository = repository;
  }

  @Override
  @Transactional
  public void run(ApplicationArguments args) {
    for (var entry : ConfigurableHomeworkOrganizerModelClient.shorthandEntries(
        properties.getHomeworkShorthand())) {
      String code = stableCode(entry.subject(), entry.term());
      if (repository.existsById(code)) continue;
      var row = new HomeworkOrganizerRuleEntity();
      row.code = code;
      row.ruleType = "SHORTHAND";
      row.scope = "GLOBAL";
      row.studentId = null;
      row.familyId = null;
      row.teacherName = "";
      row.subject = entry.subject();
      row.triggerText = entry.term();
      row.meaning = entry.meaning();
      row.shortTitle = entry.shortTitle();
      row.promptText = "";
      row.templateKey = "";
      row.priority = 10; // Legacy extra entries were appended after original 10.
      row.enabled = true;
      row.version = 1;
      row.origin = "ENV_MIGRATED";
      row.createdAt = Instant.now();
      row.updatedAt = row.createdAt;
      repository.save(row);
    }
  }

  static String stableCode(String subject, String term) {
    try {
      byte[] data = (subject + "\u001f" + term).getBytes(StandardCharsets.UTF_8);
      byte[] hash = MessageDigest.getInstance("SHA-256").digest(data);
      return "LEGACY_ENV_" + HexFormat.of().formatHex(hash).substring(0, 24);
    } catch (java.security.NoSuchAlgorithmException impossible) {
      throw new IllegalStateException(impossible);
    }
  }
}
