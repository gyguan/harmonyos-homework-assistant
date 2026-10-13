package com.xiaoban.homework.coverage;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public final class DailyHomeworkCoverageDtos {
  private DailyHomeworkCoverageDtos() {}

  public record UpdateRequest(
      @NotNull @Size(max = 4) List<String> subjects) {}

  public record ParentCoverage(
      String displayName,
      boolean mine,
      List<String> subjects,
      Instant updatedAt) {}

  public record Response(
      String studentId,
      String studentName,
      LocalDate taskDate,
      List<ParentCoverage> parents) {}
}
