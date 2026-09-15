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
}
