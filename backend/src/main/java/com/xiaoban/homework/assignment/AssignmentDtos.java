package com.xiaoban.homework.assignment;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public final class AssignmentDtos {
  private AssignmentDtos() {}
  public record Create(@NotBlank String id, @NotBlank String subject, @NotBlank String title,
      @NotBlank String instruction, String textbookRef, String dueText, @NotBlank String status,
      String sourceLabel, String sourceExcerpt, @Min(1) @Max(240) Integer expectedMinutes,
      Long startedAtEpochMs, Long finishedAtEpochMs, Long elapsedSeconds) {}
  public record Update(@NotNull Long version, String subject, String title, String instruction,
      String textbookRef, String dueText, String status, String sourceLabel, String sourceExcerpt,
      @Min(1) @Max(240) Integer expectedMinutes, Long startedAtEpochMs,
      Long finishedAtEpochMs, Long elapsedSeconds) {}
  public record Response(String id, String studentId, String subject, String title, String instruction,
      String textbookRef, String dueText, String status, String sourceLabel, String sourceExcerpt,
      int expectedMinutes, long startedAtEpochMs, long finishedAtEpochMs, long elapsedSeconds, long version) {
    static Response from(AssignmentEntity e) { return new Response(e.id, e.studentId, e.subject, e.title, e.instruction,
        e.textbookRef, e.dueText, e.status, e.sourceLabel, e.sourceExcerpt, e.expectedMinutes,
        e.startedAtEpochMs, e.finishedAtEpochMs, e.elapsedSeconds, e.version); }
  }
}
