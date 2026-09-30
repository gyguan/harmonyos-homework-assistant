package com.xiaoban.homework.scheduledassignment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialAssignmentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialDtos;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ScheduledAssignmentAttemptServiceTest {
  private final ScheduledAssignmentPlanRepository plans =
      mock(ScheduledAssignmentPlanRepository.class);
  private final ScheduledAssignmentTemplateRepository templates =
      mock(ScheduledAssignmentTemplateRepository.class);
  private final ScheduledAssignmentRunRepository runs =
      mock(ScheduledAssignmentRunRepository.class);
  private final AssignmentService assignments = mock(AssignmentService.class);
  private final VoiceMaterialAssignmentService voiceAssignments =
      mock(VoiceMaterialAssignmentService.class);

  private ScheduledAssignmentAttemptService service() {
    return new ScheduledAssignmentAttemptService(
        plans, templates, runs, assignments, voiceAssignments);
  }

  @Test
  void studentEntryRetriesTodayAfterRetryableNoMaterialSkip() {
    UUID familyId = UUID.randomUUID();
    UUID planId = UUID.randomUUID();
    Instant fireAt = Instant.parse("2026-09-27T22:30:00Z");
    Instant executionAt = Instant.parse("2026-09-28T00:00:00Z");

    ScheduledAssignmentPlanEntity plan = voicePlan(familyId, planId);
    plan.nextFireAt = Instant.parse("2026-09-28T22:30:00Z");

    ScheduledAssignmentRunEntity run = run(planId, fireAt);
    run.status = "SKIPPED";
    run.skipReason = "NO_MATERIAL";
    run.finishedAt = Instant.parse("2026-09-27T22:30:05Z");

    VoiceMaterialDtos.AutoCreateResponse created =
        new VoiceMaterialDtos.AutoCreateResponse(
            true, "2026-09-28", UUID.randomUUID().toString(), "a-voice-1", null);

    when(plans.lockById(planId)).thenReturn(Optional.of(plan));
    when(runs.findByPlanIdAndScheduledFireAt(planId, fireAt)).thenReturn(Optional.of(run));
    when(voiceAssignments.autoCreateNext(familyId, "student-1")).thenReturn(created);

    VoiceMaterialDtos.AutoCreateResponse result =
        service().executeStudentEntry(familyId, "student-1", planId, fireAt, executionAt);

    assertTrue(result.created());
    assertEquals("SUCCESS", run.status);
    assertEquals("a-voice-1", run.assignmentId);
    verify(voiceAssignments).autoCreateNext(familyId, "student-1");
  }

  @Test
  void missedSameDayDueWindowSkipsInsteadOfCreatingExpiredAssignment() {
    UUID familyId = UUID.randomUUID();
    UUID planId = UUID.randomUUID();
    Instant fireAt = Instant.parse("2026-09-28T09:00:00Z");
    Instant executionAt = Instant.parse("2026-09-28T14:00:00Z");

    ScheduledAssignmentPlanEntity plan = manualPlan(familyId, planId, fireAt);
    ScheduledAssignmentTemplateEntity template = template(planId);
    template.duePolicy = "SAME_DAY_AT";
    template.dueTime = LocalTime.of(21, 0);

    when(plans.lockById(planId)).thenReturn(Optional.of(plan));
    when(runs.findByPlanIdAndScheduledFireAt(planId, fireAt)).thenReturn(Optional.empty());
    when(runs.saveAndFlush(any(ScheduledAssignmentRunEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    when(templates.findById(planId)).thenReturn(Optional.of(template));

    service().executeScheduler(planId, fireAt, executionAt);

    verify(assignments, never()).create(any(UUID.class), any(String.class), any(AssignmentDtos.Create.class));
    ArgumentCaptor<ScheduledAssignmentRunEntity> run =
        ArgumentCaptor.forClass(ScheduledAssignmentRunEntity.class);
    verify(runs).save(run.capture());
    assertEquals("SKIPPED", run.getValue().status);
    assertEquals("MISSED_DUE_WINDOW", run.getValue().skipReason);
    assertEquals("ENDED", plan.status);
  }

  @Test
  void manualScheduledAssignmentAddsFireDateToInstanceTitle() {
    UUID familyId = UUID.randomUUID();
    UUID planId = UUID.randomUUID();
    Instant fireAt = Instant.parse("2026-09-30T09:00:00Z");
    Instant executionAt = Instant.parse("2026-09-30T09:00:05Z");

    ScheduledAssignmentPlanEntity plan = manualPlan(familyId, planId, fireAt);
    plan.scheduleType = "DAILY";
    ScheduledAssignmentTemplateEntity template = template(planId);
    template.duePolicy = "AFTER_MINUTES";
    template.dueOffsetMinutes = 60;

    when(plans.lockById(planId)).thenReturn(Optional.of(plan));
    when(runs.findByPlanIdAndScheduledFireAt(planId, fireAt)).thenReturn(Optional.empty());
    when(runs.saveAndFlush(any(ScheduledAssignmentRunEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    when(templates.findById(planId)).thenReturn(Optional.of(template));
    when(assignments.create(any(UUID.class), any(String.class), any(AssignmentDtos.Create.class)))
        .thenAnswer(invocation -> {
          AssignmentDtos.Create create = invocation.getArgument(2);
          return new AssignmentDtos.Response(
              create.id(), "student-1", create.assignmentType(), create.subjectCode(),
              create.contentType(), create.subject(), create.title(), create.instruction(),
              create.textbookRef(), create.dueAtEpochMs() == null ? 0L : create.dueAtEpochMs(),
              create.dueTimezone(), create.dueText(), create.status(), create.sourceLabel(),
              create.sourceExcerpt(), create.expectedMinutes(), 0L, 0L, 0L, "", 0L);
        });

    service().executeScheduler(planId, fireAt, executionAt);

    ArgumentCaptor<AssignmentDtos.Create> create =
        ArgumentCaptor.forClass(AssignmentDtos.Create.class);
    verify(assignments).create(
        org.mockito.ArgumentMatchers.eq(familyId),
        org.mockito.ArgumentMatchers.eq("student-1"),
        create.capture());
    assertEquals("阅读 20 分钟 · 09-30", create.getValue().title());
    assertEquals("阅读 20 分钟", template.title);
  }

  @Test
  void failureRecordSurvivesAsIndependentRetryStateAndAdvancesAfterThirdFailure() {
    UUID familyId = UUID.randomUUID();
    UUID planId = UUID.randomUUID();
    Instant fireAt = Instant.parse("2026-09-28T09:00:00Z");
    Instant executionAt = Instant.parse("2026-09-28T09:00:10Z");

    ScheduledAssignmentPlanEntity plan = manualPlan(familyId, planId, fireAt);
    plan.scheduleType = "DAILY";

    ScheduledAssignmentRunEntity run = run(planId, fireAt);
    run.status = "FAILED";
    run.retryCount = 2;
    run.errorMessage = "previous";

    when(plans.lockById(planId)).thenReturn(Optional.of(plan));
    when(runs.findByPlanIdAndScheduledFireAt(planId, fireAt)).thenReturn(Optional.of(run));

    service().recordFailure(
        planId, fireAt, "SCHEDULER", executionAt, new IllegalStateException("boom"));

    assertEquals("FAILED", run.status);
    assertEquals(3, run.retryCount);
    assertEquals("boom", run.errorMessage);
    assertEquals(Instant.parse("2026-09-29T09:00:00Z"), plan.nextFireAt);
  }

  private ScheduledAssignmentPlanEntity voicePlan(UUID familyId, UUID planId) {
    ScheduledAssignmentPlanEntity plan = new ScheduledAssignmentPlanEntity();
    plan.id = planId;
    plan.familyId = familyId;
    plan.studentId = "student-1";
    plan.planType = "VOICE_MATERIAL_AUTO";
    plan.name = "每日语音作业";
    plan.scheduleType = "DAILY";
    plan.scheduleTime = LocalTime.of(6, 30);
    plan.weekdays = "";
    plan.startDate = LocalDate.of(2026, 9, 1);
    plan.timezone = "Asia/Shanghai";
    plan.status = "ENABLED";
    plan.createdAt = Instant.parse("2026-09-01T00:00:00Z");
    plan.updatedAt = plan.createdAt;
    return plan;
  }

  private ScheduledAssignmentPlanEntity manualPlan(
      UUID familyId, UUID planId, Instant fireAt) {
    ScheduledAssignmentPlanEntity plan = new ScheduledAssignmentPlanEntity();
    plan.id = planId;
    plan.familyId = familyId;
    plan.studentId = "student-1";
    plan.planType = "MANUAL_ASSIGNMENT";
    plan.name = "每天阅读";
    plan.scheduleType = "ONCE";
    plan.scheduleTime = LocalTime.of(17, 0);
    plan.weekdays = "";
    plan.startDate = LocalDate.of(2026, 9, 28);
    plan.timezone = "Asia/Shanghai";
    plan.status = "ENABLED";
    plan.nextFireAt = fireAt;
    plan.createdAt = fireAt.minusSeconds(3600);
    plan.updatedAt = plan.createdAt;
    return plan;
  }

  private ScheduledAssignmentTemplateEntity template(UUID planId) {
    ScheduledAssignmentTemplateEntity template = new ScheduledAssignmentTemplateEntity();
    template.planId = planId;
    template.assignmentType = "EXTRA";
    template.subject = "语文";
    template.subjectCode = "CHINESE";
    template.title = "阅读 20 分钟";
    template.instruction = "阅读后复述主要内容";
    template.expectedMinutes = 20;
    return template;
  }

  private ScheduledAssignmentRunEntity run(UUID planId, Instant fireAt) {
    ScheduledAssignmentRunEntity run = new ScheduledAssignmentRunEntity();
    run.id = UUID.randomUUID();
    run.planId = planId;
    run.scheduledFireAt = fireAt;
    run.triggerSource = "SCHEDULER";
    run.status = "PENDING";
    run.skipReason = "";
    run.errorMessage = "";
    run.createdAt = fireAt;
    return run;
  }
}
