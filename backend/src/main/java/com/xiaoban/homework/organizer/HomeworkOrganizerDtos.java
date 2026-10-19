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
      String duplicateReason) {}

  public record Response(List<Candidate> assignments, String mode) {}

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

  public record ImageResponse(List<Candidate> assignments, String mode, String recognizedText) {}
}
