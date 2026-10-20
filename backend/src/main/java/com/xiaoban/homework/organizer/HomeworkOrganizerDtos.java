package com.xiaoban.homework.organizer;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class HomeworkOrganizerDtos {
  private HomeworkOrganizerDtos() {}

  public record Request(
      @NotBlank @Size(max = 12000) String text,
      @Size(max = 200) String sourceLabel,
      @Size(max = 80) String teacherName,
      @Size(max = 140) String importId) {
    public Request(String text, String sourceLabel) { this(text, sourceLabel, "", ""); }
    public Request(String text, String sourceLabel, String teacherName) {
      this(text, sourceLabel, teacherName, "");
    }
  }

  public record Candidate(
      String subject,
      String title,
      String instruction,
      String textbookRef,
      String taskDate,
      int expectedMinutes,
      String sourceExcerpt,
      double confidence,
      String sameTaskGroup,
      String duplicateAssignmentId,
      String duplicateAssignmentTitle,
      double duplicateConfidence,
      String duplicateReason,
      List<String> sourceBlockIds) {
    public Candidate {
      sourceBlockIds = sourceBlockIds == null ? List.of() : List.copyOf(sourceBlockIds);
    }
    public Candidate(String subject, String title, String instruction, String textbookRef,
        String taskDate, int expectedMinutes, String sourceExcerpt, double confidence,
        String sameTaskGroup, String duplicateAssignmentId, String duplicateAssignmentTitle,
        double duplicateConfidence, String duplicateReason) {
      this(subject, title, instruction, textbookRef, taskDate, expectedMinutes, sourceExcerpt,
          confidence, sameTaskGroup, duplicateAssignmentId, duplicateAssignmentTitle,
          duplicateConfidence, duplicateReason, List.of());
    }
  }

  public record ExperienceUsage(List<String> retrievedExperienceIds, List<String> appliedExperienceIds,
      List<String> unsupportedAppliedExperienceIds) {
    public static ExperienceUsage empty() { return new ExperienceUsage(List.of(), List.of(), List.of()); }
  }

  public record QualityFlag(String code, List<String> sourceBlockIds, List<Integer> assignmentIndexes) {}

  public record Response(List<Candidate> assignments, String mode,
      HomeworkSourceDocument sourceDocument, List<QualityFlag> qualityFlags, boolean needsReview, ExperienceUsage experiences) {
    public Response(List<Candidate> assignments, String mode, HomeworkSourceDocument document,
        List<QualityFlag> flags, boolean needsReview) {
      this(assignments, mode, document, flags, needsReview, ExperienceUsage.empty());
    }
    public Response(List<Candidate> assignments, String mode) {
      this(assignments, mode, null, List.of(), false);
    }
  }

  public record ImageRequest(
      @NotBlank @Size(max = 5592408) String imageBase64,
      @NotBlank @Size(max = 30) String contentType,
      @Size(max = 200) String sourceLabel,
      @Size(max = 12000) String text,
      @Size(max = 80) String teacherName,
      @Size(max = 140) String importId) {
    public ImageRequest(String imageBase64, String contentType, String sourceLabel, String text) {
      this(imageBase64, contentType, sourceLabel, text, "", "");
    }
    public ImageRequest(String imageBase64, String contentType, String sourceLabel, String text,
        String teacherName) {
      this(imageBase64, contentType, sourceLabel, text, teacherName, "");
    }
  }

  public record ImageResponse(List<Candidate> assignments, String mode, String recognizedText,
      HomeworkSourceDocument sourceDocument, List<QualityFlag> qualityFlags, boolean needsReview, ExperienceUsage experiences) {
    public ImageResponse(List<Candidate> assignments, String mode, String recognizedText, HomeworkSourceDocument document,
        List<QualityFlag> flags, boolean needsReview) {
      this(assignments, mode, recognizedText, document, flags, needsReview, ExperienceUsage.empty());
    }
    public ImageResponse(List<Candidate> assignments, String mode, String recognizedText) {
      this(assignments, mode, recognizedText, null, List.of(), false);
    }
  }
}
