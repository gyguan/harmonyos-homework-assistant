package com.xiaoban.homework.organizer;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class HomeworkTeacherExperienceDtos {
  private HomeworkTeacherExperienceDtos() {}

  public record Upsert(
      @NotBlank @Size(max = 80) String teacherName,
      @NotBlank @Size(max = 20) String subject,
      @NotBlank @Size(max = 120) String cue,
      @NotBlank @Size(max = 600) String interpretation,
      @Size(max = 400) String exampleSource,
      @Size(max = 400) String exampleResult) {}

  /** 家长确认时发生过的修改；这只是例子，绝不自动上升为普遍规则。 */
  public record ConfirmedEdit(
      @NotBlank @Size(max = 80) String teacherName,
      @NotBlank @Size(max = 20) String subject,
      @NotBlank @Size(max = 120) String sourceExcerpt,
      @NotBlank @Size(max = 400) String beforeTitle,
      @NotBlank @Size(max = 400) String afterTitle) {}

  public record ActiveUpdate(boolean active) {}

  public record Response(UUID id, String teacherName, String subject, String cue,
      String interpretation, String exampleSource, String exampleResult, String origin,
      Instant updatedAt, boolean active, UUID sourceFeedbackId) {
    static Response from(HomeworkTeacherExperienceEntity entity) {
      return new Response(entity.id, entity.teacherName, entity.subject,
          entity.cue, entity.interpretation, entity.exampleSource, entity.exampleResult,
          entity.origin, entity.updatedAt, entity.active, entity.sourceFeedbackId);
    }
  }
}
