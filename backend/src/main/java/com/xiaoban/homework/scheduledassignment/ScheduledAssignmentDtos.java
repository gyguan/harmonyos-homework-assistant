package com.xiaoban.homework.scheduledassignment;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public final class ScheduledAssignmentDtos {
  private ScheduledAssignmentDtos() {}

  public record TemplateInput(
      String assignmentType,
      @NotBlank @Size(max = 300) String title,
      @NotBlank @Size(max = 1000) String instruction,
      Integer expectedMinutes) {}

  public record UpsertRequest(
      @NotBlank String planType,
      @NotBlank @Size(max = 64) String subjectCode,
      @NotBlank @Size(max = 300) String name,
      @NotBlank String scheduleType,
      @NotBlank String timeOfDay,
      List<String> weekdays,
      @NotBlank String startDate,
      String endDate,
      @Valid TemplateInput template) {}

  public record UpdateRequest(
      @NotNull Long version,
      @NotBlank String planType,
      @NotBlank @Size(max = 64) String subjectCode,
      @NotBlank @Size(max = 300) String name,
      @NotBlank String scheduleType,
      @NotBlank String timeOfDay,
      List<String> weekdays,
      @NotBlank String startDate,
      String endDate,
      @Valid TemplateInput template) {}

  public record ActionRequest(@NotBlank String action, @NotNull Long version) {}

  public record TemplateResponse(
      String assignmentType,
      String subject,
      String subjectCode,
      String title,
      String instruction,
      int expectedMinutes) {}

  public record PlanResponse(
      String id,
      String studentId,
      String planType,
      String subjectCode,
      String name,
      String scheduleType,
      String timeOfDay,
      List<String> weekdays,
      String startDate,
      String endDate,
      String timezone,
      String status,
      long nextFireAtEpochMs,
      long lastFireAtEpochMs,
      TemplateResponse template,
      long version) {}

  public record RunResponse(
      String id,
      long scheduledFireAtEpochMs,
      String triggerSource,
      String status,
      String assignmentId,
      String skipReason,
      String errorMessage,
      int retryCount,
      long finishedAtEpochMs) {}
}
