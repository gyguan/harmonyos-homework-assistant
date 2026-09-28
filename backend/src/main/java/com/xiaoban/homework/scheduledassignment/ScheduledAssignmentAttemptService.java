package com.xiaoban.homework.scheduledassignment;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.voicematerial.VoiceMaterialAssignmentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialDtos;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ScheduledAssignmentAttemptService {
  private static final int MAX_RETRIES = 3;
  private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm");

  private final ScheduledAssignmentPlanRepository plans;
  private final ScheduledAssignmentTemplateRepository templates;
  private final ScheduledAssignmentRunRepository runs;
  private final AssignmentService assignments;
  private final VoiceMaterialAssignmentService voiceAssignments;

  public ScheduledAssignmentAttemptService(
      ScheduledAssignmentPlanRepository plans,
      ScheduledAssignmentTemplateRepository templates,
      ScheduledAssignmentRunRepository runs,
      AssignmentService assignments,
      VoiceMaterialAssignmentService voiceAssignments) {
    this.plans = plans;
    this.templates = templates;
    this.runs = runs;
    this.assignments = assignments;
    this.voiceAssignments = voiceAssignments;
  }

  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void executeScheduler(UUID planId, Instant expectedFireAt, Instant executionAt) {
    ScheduledAssignmentPlanEntity plan = plans.lockById(planId).orElse(null);
    if (plan == null || !"ENABLED".equals(plan.status) || plan.nextFireAt == null ||
        !plan.nextFireAt.equals(expectedFireAt) || expectedFireAt.isAfter(executionAt)) {
      return;
    }
    if ("VOICE_MATERIAL_AUTO".equals(plan.planType)) {
      executeVoiceLocked(plan, expectedFireAt, "SCHEDULER", executionAt);
    } else {
      executeManualLocked(plan, expectedFireAt, executionAt);
    }
  }

  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public VoiceMaterialDtos.AutoCreateResponse executeStudentEntry(
      UUID familyId, String studentId, UUID planId, Instant fireAt, Instant executionAt) {
    ScheduledAssignmentPlanEntity plan = plans.lockById(planId).orElse(null);
    if (plan == null || !familyId.equals(plan.familyId) || !studentId.equals(plan.studentId) ||
        !"ENABLED".equals(plan.status) || !"VOICE_MATERIAL_AUTO".equals(plan.planType)) {
      return emptyVoiceResponse();
    }

    LocalDate businessDate = executionAt.atZone(ScheduledAssignmentSchedule.BUSINESS_ZONE).toLocalDate();
    Instant todayFireAt = ScheduledAssignmentSchedule.fireAt(plan, businessDate);
    if (todayFireAt == null || !todayFireAt.equals(fireAt) || fireAt.isAfter(executionAt)) {
      return emptyVoiceResponse();
    }
    return executeVoiceLocked(plan, fireAt, "STUDENT_ENTRY", executionAt);
  }

  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void recordFailure(UUID planId, Instant fireAt, String triggerSource,
      Instant executionAt, RuntimeException error) {
    ScheduledAssignmentPlanEntity plan = plans.lockById(planId).orElse(null);
    if (plan == null) return;

    ScheduledAssignmentRunEntity run = prepareRun(plan.id, fireAt, triggerSource, executionAt);
    if (isFinal(run)) return;

    run.status = "FAILED";
    run.retryCount++;
    run.skipReason = "";
    String message = error.getMessage();
    run.errorMessage = message == null ? error.getClass().getSimpleName() :
        message.substring(0, Math.min(message.length(), 500));
    run.finishedAt = executionAt;
    runs.save(run);

    if (run.retryCount >= MAX_RETRIES && "ENABLED".equals(plan.status)) {
      advance(plan, fireAt, executionAt);
    }
  }

  private void executeManualLocked(
      ScheduledAssignmentPlanEntity plan, Instant fireAt, Instant executionAt) {
    ScheduledAssignmentRunEntity run = prepareRun(plan.id, fireAt, "SCHEDULER", executionAt);
    if (isFinal(run)) {
      advance(plan, fireAt, executionAt);
      return;
    }

    ScheduledAssignmentTemplateEntity template = templates.findById(plan.id)
        .orElseThrow(() -> new ApiExceptions.BadRequest("普通定时作业缺少任务模板"));
    Instant dueAt = dueAt(plan, template, executionAt);
    if ("SAME_DAY_AT".equals(template.duePolicy) &&
        dueAt != null && !dueAt.isAfter(executionAt)) {
      finishSkipped(run, "MISSED_DUE_WINDOW", executionAt);
      advance(plan, fireAt, executionAt);
      return;
    }

    String assignmentId = "a-scheduled-" + plan.id + "-" + fireAt.toEpochMilli();
    AssignmentDtos.Create create = new AssignmentDtos.Create(
        assignmentId,
        template.subject,
        template.title,
        template.instruction,
        "",
        dueText(template),
        template.assignmentType,
        template.subjectCode,
        "NORMAL",
        dueAt == null ? null : dueAt.toEpochMilli(),
        plan.timezone,
        "NOT_STARTED",
        "定时作业",
        plan.name,
        template.expectedMinutes,
        0L,
        0L,
        0L,
        "");

    AssignmentDtos.Response assignment =
        assignments.create(plan.familyId, plan.studentId, create);
    run.status = "SUCCESS";
    run.assignmentId = assignment.id();
    run.skipReason = "";
    run.errorMessage = "";
    run.finishedAt = executionAt;
    runs.save(run);
    advance(plan, fireAt, executionAt);
  }

  private VoiceMaterialDtos.AutoCreateResponse executeVoiceLocked(
      ScheduledAssignmentPlanEntity plan, Instant fireAt, String triggerSource,
      Instant executionAt) {
    ScheduledAssignmentRunEntity run = prepareRun(plan.id, fireAt, triggerSource, executionAt);
    if (isFinal(run)) return emptyVoiceResponse();

    VoiceMaterialDtos.AutoCreateResponse result =
        voiceAssignments.autoCreateNext(plan.familyId, plan.studentId);
    if (result.created()) {
      run.status = "SUCCESS";
      run.assignmentId = blankToNull(result.assignmentId());
      run.skipReason = "";
    } else {
      run.status = "SKIPPED";
      run.assignmentId = blankToNull(result.assignmentId());
      run.skipReason = voiceSkipReason(result);
    }
    run.errorMessage = "";
    run.finishedAt = executionAt;
    runs.save(run);

    // Scheduler advances after every handled attempt so it does not poll a blocked/no-material
    // plan every 30 seconds. Student entry can still retry today's retryable SKIPPED run.
    advance(plan, fireAt, executionAt);
    return result;
  }

  private ScheduledAssignmentRunEntity prepareRun(
      UUID planId, Instant fireAt, String triggerSource, Instant executionAt) {
    ScheduledAssignmentRunEntity existing =
        runs.findByPlanIdAndScheduledFireAt(planId, fireAt).orElse(null);
    if (existing != null) {
      if (!isFinal(existing)) existing.triggerSource = triggerSource;
      return existing;
    }

    ScheduledAssignmentRunEntity run = new ScheduledAssignmentRunEntity();
    run.id = UUID.randomUUID();
    run.planId = planId;
    run.scheduledFireAt = fireAt;
    run.triggerSource = triggerSource;
    run.status = "PENDING";
    run.assignmentId = null;
    run.skipReason = "";
    run.errorMessage = "";
    run.retryCount = 0;
    run.createdAt = executionAt;
    run.finishedAt = null;
    return runs.saveAndFlush(run);
  }

  private boolean isFinal(ScheduledAssignmentRunEntity run) {
    if ("SUCCESS".equals(run.status)) return true;
    if ("FAILED".equals(run.status) && run.retryCount >= MAX_RETRIES) return true;
    if (!"SKIPPED".equals(run.status)) return false;
    return "ALREADY_CREATED_TODAY".equals(run.skipReason) ||
        "MISSED_DUE_WINDOW".equals(run.skipReason);
  }

  private void finishSkipped(
      ScheduledAssignmentRunEntity run, String reason, Instant executionAt) {
    run.status = "SKIPPED";
    run.skipReason = reason;
    run.errorMessage = "";
    run.finishedAt = executionAt;
    runs.save(run);
  }

  private void advance(
      ScheduledAssignmentPlanEntity plan, Instant fireAt, Instant executionAt) {
    plan.lastFireAt = fireAt;
    Instant next = ScheduledAssignmentSchedule.nextFire(plan, executionAt);
    plan.nextFireAt = next;
    if (next == null) plan.status = "ENDED";
    plan.updatedAt = executionAt;
    plans.save(plan);
  }

  private Instant dueAt(ScheduledAssignmentPlanEntity plan,
      ScheduledAssignmentTemplateEntity template, Instant executionAt) {
    ZoneId zone = ScheduledAssignmentSchedule.zone(plan.timezone);
    LocalDate date = executionAt.atZone(zone).toLocalDate();
    return switch (template.duePolicy) {
      case "SAME_DAY_AT" -> date.atTime(template.dueTime).atZone(zone).toInstant();
      case "NEXT_DAY_AT" -> date.plusDays(1).atTime(template.dueTime).atZone(zone).toInstant();
      case "AFTER_MINUTES" -> executionAt.plusSeconds((long) template.dueOffsetMinutes * 60L);
      case "NONE" -> null;
      default -> throw new ApiExceptions.BadRequest("不支持的截止规则: " + template.duePolicy);
    };
  }

  private String dueText(ScheduledAssignmentTemplateEntity template) {
    return switch (template.duePolicy) {
      case "SAME_DAY_AT" -> "今天 " + template.dueTime.format(TIME_FORMAT);
      case "NEXT_DAY_AT" -> "明天 " + template.dueTime.format(TIME_FORMAT);
      case "AFTER_MINUTES" -> "创建后 " + template.dueOffsetMinutes + " 分钟";
      default -> "未定";
    };
  }

  private String voiceSkipReason(VoiceMaterialDtos.AutoCreateResponse result) {
    if (result.assignment() != null) return "ACTIVE_TASK_EXISTS";
    if (!text(result.packageId()).isBlank() || !text(result.assignmentId()).isBlank()) {
      return "ALREADY_CREATED_TODAY";
    }
    return "NO_MATERIAL";
  }

  private VoiceMaterialDtos.AutoCreateResponse emptyVoiceResponse() {
    return new VoiceMaterialDtos.AutoCreateResponse(
        false, LocalDate.now(ScheduledAssignmentSchedule.BUSINESS_ZONE).toString(),
        "", "", null);
  }

  private String text(String value) { return value == null ? "" : value; }

  private String blankToNull(String value) {
    String normalized = text(value).trim();
    return normalized.isBlank() ? null : normalized;
  }
}
