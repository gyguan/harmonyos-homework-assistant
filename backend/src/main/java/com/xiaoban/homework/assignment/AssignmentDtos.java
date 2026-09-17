package com.xiaoban.homework.assignment;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class AssignmentDtos {
  private AssignmentDtos() {}

  public record Create(@NotBlank String id, @NotBlank String subject, @NotBlank String title,
      @NotBlank String instruction, String textbookRef, String dueText,
      String assignmentType, String subjectCode, Long dueAtEpochMs, String dueTimezone,
      @NotBlank String status, String sourceLabel, String sourceExcerpt,
      @Min(1) @Max(240) Integer expectedMinutes,
      Long startedAtEpochMs, Long finishedAtEpochMs, Long elapsedSeconds,
      @Size(max = 1000) String reviewNote) {}

  public record Update(@NotNull Long version, String subject, String title, String instruction,
      String textbookRef, String dueText, String assignmentType, String subjectCode,
      Long dueAtEpochMs, String dueTimezone, String status, String sourceLabel, String sourceExcerpt,
      @Min(1) @Max(240) Integer expectedMinutes, Long startedAtEpochMs,
      Long finishedAtEpochMs, Long elapsedSeconds, @Size(max = 1000) String reviewNote) {}

  public record ActionRequest(@NotBlank String action, @NotNull Long version) {}

  public record ReviewRequest(@NotBlank String decision, @NotNull Long version,
      @Size(max = 1000) String note) {}

  public record BatchCreateRequest(@NotNull @Size(min = 1, max = 50) List<Create> assignments) {}

  public record BatchCreateItemResult(String assignmentId, String outcome, String message,
      Response assignment) {}

  public record BatchCreateResponse(int requested, int succeeded, int failed,
      List<BatchCreateItemResult> results) {}

  public record Response(String id, String studentId, String assignmentType, String subjectCode,
      String subject, String title, String instruction, String textbookRef,
      long dueAtEpochMs, String dueTimezone, String dueText, String status,
      String sourceLabel, String sourceExcerpt, int expectedMinutes,
      long startedAtEpochMs, long finishedAtEpochMs, long elapsedSeconds,
      String reviewNote, long version) {
    public static Response from(AssignmentEntity e) {
      return new Response(e.id, e.studentId, e.assignmentType, e.subjectCode, e.subject,
          e.title, e.instruction, e.textbookRef,
          e.dueAt == null ? 0L : e.dueAt.toEpochMilli(), e.dueTimezone, e.dueText,
          e.status, e.sourceLabel, e.sourceExcerpt, e.expectedMinutes,
          e.startedAtEpochMs, e.finishedAtEpochMs, e.elapsedSeconds, e.reviewNote, e.version);
    }
  }

  public record TodaySummary(int total, int completed, int attention,
      int undated, String nextAssignmentId) {}
}
