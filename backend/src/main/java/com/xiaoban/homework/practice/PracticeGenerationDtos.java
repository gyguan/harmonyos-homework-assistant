package com.xiaoban.homework.practice;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import java.util.List;

public final class PracticeGenerationDtos {
  private PracticeGenerationDtos() {}

  public record GenerateRequest(
      @NotBlank String subject,
      @NotBlank String track,
      @NotBlank String difficulty,
      @Min(5) @Max(20) int questionCount,
      @NotBlank String requirement) {}

  public record DraftQuestion(
      String id,
      int orderNo,
      String type,
      String stem,
      List<PracticeDtos.Option> options,
      String answerSpec,
      String explanation,
      List<String> hints,
      List<String> tags) {}

  public record DraftPaper(
      String id,
      int version,
      String grade,
      String subject,
      String semester,
      String track,
      String title,
      String description,
      String difficulty,
      int questionCount,
      int estimatedMinutes,
      List<String> tags,
      String sourceType,
      List<DraftQuestion> questions) {}

  public record AudienceCandidate(
      String studentId,
      String studentName,
      String grade,
      String semester,
      boolean compatible,
      String reason) {}

  public record GenerationResponse(
      String generationId,
      String status,
      DraftPaper paper,
      String errorMessage,
      List<AudienceCandidate> audienceCandidates) {}

  public record PublishRequest(
      @NotBlank String scope,
      List<String> targetStudentIds,
      String purpose) {
    public PublishRequest(String scope, List<String> targetStudentIds) {
      this(scope, targetStudentIds, "STANDARD");
    }
  }

  public record PublishResponse(
      String generationId,
      String status,
      PracticeDtos.PaperResponse paper,
      List<String> targetStudentIds) {}
}
