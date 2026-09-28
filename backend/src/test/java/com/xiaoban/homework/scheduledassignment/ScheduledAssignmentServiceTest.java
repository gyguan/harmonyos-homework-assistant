package com.xiaoban.homework.scheduledassignment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialAssignmentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialDtos;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ScheduledAssignmentServiceTest {
  private final ScheduledAssignmentPlanRepository plans =
      mock(ScheduledAssignmentPlanRepository.class);
  private final ScheduledAssignmentTemplateRepository templates =
      mock(ScheduledAssignmentTemplateRepository.class);
  private final ScheduledAssignmentRunRepository runs =
      mock(ScheduledAssignmentRunRepository.class);
  private final StudentService students = mock(StudentService.class);
  private final VoiceMaterialAssignmentService voiceAssignments =
      mock(VoiceMaterialAssignmentService.class);
  private final ScheduledAssignmentAttemptService attempts =
      mock(ScheduledAssignmentAttemptService.class);

  private ScheduledAssignmentService service() {
    return new ScheduledAssignmentService(
        plans, templates, runs, students, voiceAssignments, attempts);
  }

  @Test
  void studentEntryKeepsLegacyVoiceBehaviorWhenNoScheduleExists() {
    UUID familyId = UUID.randomUUID();
    VoiceMaterialDtos.AutoCreateResponse expected =
        new VoiceMaterialDtos.AutoCreateResponse(false, "2026-09-28", "", "", null);
    when(plans.findByFamilyIdAndStudentIdAndPlanTypeOrderByCreatedAtDesc(
        familyId, "student-1", "VOICE_MATERIAL_AUTO")).thenReturn(List.of());
    when(voiceAssignments.autoCreateNext(familyId, "student-1")).thenReturn(expected);

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateOnStudentEntry(familyId, "student-1");

    assertEquals(expected, result);
    verify(students).requireOwned(familyId, "student-1");
    verify(students, never()).requireOwnedForUpdate(any(UUID.class), anyString());
    verify(voiceAssignments).autoCreateNext(familyId, "student-1");
  }

  @Test
  void studentEntryDoesNotCreateVoiceTaskBeforePlanStartDate() {
    UUID familyId = UUID.randomUUID();
    LocalDate tomorrow = LocalDate.now(ScheduledAssignmentSchedule.BUSINESS_ZONE).plusDays(1);
    ScheduledAssignmentPlanEntity plan = voicePlan(familyId, tomorrow, LocalTime.of(0, 0));
    when(plans.findByFamilyIdAndStudentIdAndPlanTypeOrderByCreatedAtDesc(
        familyId, "student-1", "VOICE_MATERIAL_AUTO")).thenReturn(List.of(plan));

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateOnStudentEntry(familyId, "student-1");

    assertFalse(result.created());
    verify(attempts, never()).executeStudentEntry(
        any(UUID.class), anyString(), any(UUID.class), any(Instant.class), any(Instant.class));
    verify(voiceAssignments, never()).autoCreateNext(any(UUID.class), anyString());
  }

  @Test
  void studentEntryUsesTodayFireEvenWhenSchedulerAdvancedNextFireToTomorrow() {
    UUID familyId = UUID.randomUUID();
    LocalDate today = LocalDate.now(ScheduledAssignmentSchedule.BUSINESS_ZONE);
    ScheduledAssignmentPlanEntity plan = voicePlan(familyId, today.minusDays(1), LocalTime.MIDNIGHT);
    plan.nextFireAt = today.plusDays(1).atStartOfDay(ScheduledAssignmentSchedule.BUSINESS_ZONE).toInstant();

    VoiceMaterialDtos.AutoCreateResponse expected =
        new VoiceMaterialDtos.AutoCreateResponse(true, today.toString(), "pkg-1", "a-1", null);
    when(plans.findByFamilyIdAndStudentIdAndPlanTypeOrderByCreatedAtDesc(
        familyId, "student-1", "VOICE_MATERIAL_AUTO")).thenReturn(List.of(plan));
    when(attempts.executeStudentEntry(
        org.mockito.ArgumentMatchers.eq(familyId),
        org.mockito.ArgumentMatchers.eq("student-1"),
        org.mockito.ArgumentMatchers.eq(plan.id),
        any(Instant.class),
        any(Instant.class))).thenReturn(expected);

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateOnStudentEntry(familyId, "student-1");

    assertEquals(expected, result);
    verify(attempts).executeStudentEntry(
        org.mockito.ArgumentMatchers.eq(familyId),
        org.mockito.ArgumentMatchers.eq("student-1"),
        org.mockito.ArgumentMatchers.eq(plan.id),
        any(Instant.class),
        any(Instant.class));
  }

  private ScheduledAssignmentPlanEntity voicePlan(
      UUID familyId, LocalDate startDate, LocalTime scheduleTime) {
    ScheduledAssignmentPlanEntity plan = new ScheduledAssignmentPlanEntity();
    plan.id = UUID.randomUUID();
    plan.familyId = familyId;
    plan.studentId = "student-1";
    plan.planType = "VOICE_MATERIAL_AUTO";
    plan.name = "每日语音作业";
    plan.scheduleType = "DAILY";
    plan.scheduleTime = scheduleTime;
    plan.weekdays = "";
    plan.startDate = startDate;
    plan.timezone = "Asia/Shanghai";
    plan.status = "ENABLED";
    plan.createdAt = Instant.now();
    plan.updatedAt = plan.createdAt;
    return plan;
  }
}
