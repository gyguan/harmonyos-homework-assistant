package com.xiaoban.homework.organizer;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class HomeworkOrganizerDtos {
  private HomeworkOrganizerDtos() {}

  public record Request(
      @NotBlank @Size(max = 12000) String text,
      @Size(max = 200) String sourceLabel) {}

  public record Candidate(
      String subject,
      String title,
      String instruction,
      String textbookRef,
      String dueText,
      int expectedMinutes,
      String sourceExcerpt,
      double confidence) {}

  public record Response(List<Candidate> assignments, String mode) {}

  public record ImageRequest(
      @NotBlank @Size(max = 5592408) String imageBase64,
      @NotBlank @Size(max = 30) String contentType,
      @Size(max = 200) String sourceLabel,
      @Size(max = 12000) String text) {}

  public record ImageResponse(List<Candidate> assignments, String mode, String recognizedText) {}
}
