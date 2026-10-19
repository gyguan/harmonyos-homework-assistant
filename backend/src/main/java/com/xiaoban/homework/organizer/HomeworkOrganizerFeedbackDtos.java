package com.xiaoban.homework.organizer;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

public final class HomeworkOrganizerFeedbackDtos {
  private HomeworkOrganizerFeedbackDtos() {}

  public record TypeResponse(String code, String label, String description, boolean requiresComment) {
    static TypeResponse from(HomeworkFeedbackTypeEntity entity) {
      return new TypeResponse(entity.code, entity.label, entity.description, entity.requiresComment);
    }
  }

  public record Create(
      @NotBlank @Size(max = 160) String clientRequestId,
      @NotBlank @Size(max = 180) String candidateId,
      @Size(max = 180) String batchId,
      @Size(max = 80) String teacherName,
      @NotBlank @Size(max = 20) String subject,
      @NotBlank @Size(max = 48) String feedbackTypeCode,
      @Size(max = 200) String sourceLabel,
      @Size(max = 500) String sourceExcerpt,
      @Size(max = 400) String originalTitle,
      @Size(max = 400) String currentTitle,
      @Size(max = 1200) String details) {}

  public record Response(UUID id, String candidateId, String teacherName,
      String subject, String feedbackTypeCode, String details, String processingStatus,
      Instant createdAt) {
    static Response from(HomeworkOrganizerFeedbackEntity entity) {
      return new Response(entity.id, entity.candidateId, entity.teacherName,
          entity.subject, entity.feedbackTypeCode, entity.details,
          entity.processingStatus, entity.createdAt);
    }
  }
}
