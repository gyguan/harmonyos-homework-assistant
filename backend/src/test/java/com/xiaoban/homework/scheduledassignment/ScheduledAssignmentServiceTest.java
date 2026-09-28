package com.xiaoban.homework.scheduledassignment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialAssignmentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialDtos;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class ScheduledAssignmentServiceTest {
  private final ScheduledAssignmentPlanRepository plans =
      mock(ScheduledAssignmentPlanRepository.class);
  private final ScheduledAssignmentTemplateRepository templates =
      mock(ScheduledAssignmentTemplateRepository.class);
  private final ScheduledAssignmentRunRepository runs =
      mock(ScheduledAssignmentRunRepository.class);
  private final StudentService students = mock(StudentService.class);
  private final AssignmentService assignments = mock(AssignmentService.class);
  private final VoiceMaterialAssignmentService voiceAssignments =
      mock(VoiceMaterialAssignmentService.class);

  private ScheduledAssignmentService service() {
    return new ScheduledAssignmentService(
        plans, templates, runs, students, assignments, voiceAssignments);
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
    verify(voiceAssignments).autoCreateNext(familyId, "student-1");
  }

  @Test
  void studentEntryDoesNotCreateVoiceTaskBeforeScheduledTime() {
    UUID familyId = UUID.randomUUID();
    ScheduledAssignmentPlanEntity plan = voicePlan(familyId);
    plan.nextFireAt = Instant.now().plusSeconds(3600);
    when(plans.findByFamilyIdAndStudentIdAndPlanTypeOrderByCreatedAtDesc(
        familyId, "student-1", "VOICE_MATERIAL_AUTO")).thenReturn(List.of(plan));

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateOnStudentEntry(familyId, "student-1");

    assertFalse(result.created());
    verify(voiceAssignments, never()).autoCreateNext(any(UUID.class), anyString());
  }

  @Test
  void dueManualPlanCreatesDeterministicAssignmentAndAdvancesSchedule() {
    UUID familyId = UUID.randomUUID();
    UUID planId = UUID.randomUUID();
    Instant fireAt = Instant.parse("2026-09-28T09:00:00Z");

    ScheduledAssignmentPlanEntity plan = new ScheduledAssignmentPlanEntity();
    plan.id = planId;
    plan.familyId = familyId;
    plan.studentId = "student-1";
    plan.planType = "MANUAL_ASSIGNMENT";
    plan.name = "每天阅读";
    plan.scheduleType = "DAILY";
    plan.scheduleTime = LocalTime.of(17, 0);
    plan.weekdays = "";
    plan.startDate = LocalDate.of(2026, 9, 1);
    plan.timezone = "Asia/Shanghai";
    plan.status = "ENABLED";
    plan.nextFireAt = fireAt;
    plan.createdAt = fireAt.minusSeconds(3600);
    plan.updatedAt = plan.createdAt;

    ScheduledAssignmentTemplateEntity template = new ScheduledAssignmentTemplateEntity();
    template.planId = planId;
    template.assignmentType = "EXTRA";
    template.subject = "语文";
    template.subjectCode = "CHINESE";
    template.title = "阅读 20 分钟";
    template.instruction = "阅读后复述主要内容";
    template.expectedMinutes = 20;
    template.duePolicy = "SAME_DAY_AT";
    template.dueTime = LocalTime.of(21, 0);

    when(plans.lockById(planId)).thenReturn(Optional.of(plan));
    when(runs.findByPlanIdAndScheduledFireAt(planId, fireAt)).thenReturn(Optional.empty());
    when(runs.saveAndFlush(any(ScheduledAssignmentRunEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    when(templates.findById(planId)).thenReturn(Optional.of(template));
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(assignment("a-result"));

    service().executeDuePlan(planId, fireAt.plusSeconds(1));

    ArgumentCaptor<AssignmentDtos.Create> create =
        ArgumentCaptor.forClass(AssignmentDtos.Create.class);
    verify(assignments).create(
        org.mockito.ArgumentMatchers.eq(familyId),
        org.mockito.ArgumentMatchers.eq("student-1"),
        create.capture());

    assertEquals("a-scheduled-" + planId + "-" + fireAt.toEpochMilli(), create.getValue().id());
    assertEquals(Instant.parse("2026-09-28T13:00:00Z").toEpochMilli(),
        create.getValue().dueAtEpochMs());
    assertEquals("定时作业", create.getValue().sourceLabel());
    assertEquals(Instant.parse("2026-09-29T09:00:00Z"), plan.nextFireAt);

    ArgumentCaptor<ScheduledAssignmentRunEntity> run =
        ArgumentCaptor.forClass(ScheduledAssignmentRunEntity.class);
    verify(runs).save(run.capture());
    assertEquals("SUCCESS", run.getValue().status);
    assertEquals("a-result", run.getValue().assignmentId);
    assertTrue(run.getValue().finishedAt != null);
  }

  private ScheduledAssignmentPlanEntity voicePlan(UUID familyId) {
    ScheduledAssignmentPlanEntity plan = new ScheduledAssignmentPlanEntity();
    plan.id = UUID.randomUUID();
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
    plan.createdAt = Instant.now();
    plan.updatedAt = plan.createdAt;
    return plan;
  }

  private AssignmentDtos.Response assignment(String id) {
    return new AssignmentDtos.Response(
        id, "student-1", "EXTRA", "CHINESE", "NORMAL",
        "语文", "阅读 20 分钟", "阅读后复述主要内容", "",
        0L, "Asia/Shanghai", "", "NOT_STARTED",
        "定时作业", "每天阅读", 20,
        0L, 0L, 0L, "", 0L);
  }
}
