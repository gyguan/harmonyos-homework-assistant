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
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ScheduledAssignmentAttemptService {
  private static final Logger log = LoggerFactory.getLogger(ScheduledAssignmentAttemptService.class);
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
    if (plan == null) {
      log.info("scheduled_assignment attempt_exit planId={} triggerSource=SCHEDULER reason=PLAN_NOT_FOUND expectedFireAt={}",
          planId, expectedFireAt);
      return;
    }
    if (!"ENABLED".equals(plan.status)) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} planType={} triggerSource=SCHEDULER reason=PLAN_NOT_ENABLED status={} expectedFireAt={}",
          plan.id, plan.studentId, plan.planType, plan.status, expectedFireAt);
      return;
    }
    if (plan.nextFireAt == null) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} planType={} triggerSource=SCHEDULER reason=NEXT_FIRE_AT_EMPTY expectedFireAt={}",
          plan.id, plan.studentId, plan.planType, expectedFireAt);
      return;
    }
    if (!plan.nextFireAt.equals(expectedFireAt)) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} planType={} triggerSource=SCHEDULER reason=FIRE_AT_CHANGED expectedFireAt={} actualNextFireAt={}",
          plan.id, plan.studentId, plan.planType, expectedFireAt, plan.nextFireAt);
      return;
    }
    if (expectedFireAt.isAfter(executionAt)) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} planType={} triggerSource=SCHEDULER reason=NOT_DUE expectedFireAt={} executionAt={}",
          plan.id, plan.studentId, plan.planType, expectedFireAt, executionAt);
      return;
    }

    log.info("scheduled_assignment attempt_branch planId={} studentId={} planType={} triggerSource=SCHEDULER fireAt={} executionAt={}",
        plan.id, plan.studentId, plan.planType, expectedFireAt, executionAt);
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
    if (plan == null) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} triggerSource=STUDENT_ENTRY reason=PLAN_NOT_FOUND fireAt={}",
          planId, studentId, fireAt);
      return emptyVoiceResponse();
    }
    if (!familyId.equals(plan.familyId) || !studentId.equals(plan.studentId)) {
      log.warn("scheduled_assignment attempt_exit planId={} studentId={} triggerSource=STUDENT_ENTRY reason=OWNERSHIP_MISMATCH planStudentId={} fireAt={}",
          planId, studentId, plan.studentId, fireAt);
      return emptyVoiceResponse();
    }
    if (!"ENABLED".equals(plan.status)) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} triggerSource=STUDENT_ENTRY reason=PLAN_NOT_ENABLED status={} fireAt={}",
          planId, studentId, plan.status, fireAt);
      return emptyVoiceResponse();
    }
    if (!"VOICE_MATERIAL_AUTO".equals(plan.planType)) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} triggerSource=STUDENT_ENTRY reason=NOT_VOICE_PLAN planType={} fireAt={}",
          planId, studentId, plan.planType, fireAt);
      return emptyVoiceResponse();
    }

    LocalDate businessDate = executionAt.atZone(ScheduledAssignmentSchedule.BUSINESS_ZONE).toLocalDate();
    Instant todayFireAt = ScheduledAssignmentSchedule.fireAt(plan, businessDate);
    if (todayFireAt == null) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} triggerSource=STUDENT_ENTRY reason=NOT_ELIGIBLE_TODAY businessDate={} fireAt={}",
          planId, studentId, businessDate, fireAt);
      return emptyVoiceResponse();
    }
    if (!todayFireAt.equals(fireAt)) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} triggerSource=STUDENT_ENTRY reason=FIRE_AT_MISMATCH expectedTodayFireAt={} suppliedFireAt={}",
          planId, studentId, todayFireAt, fireAt);
      return emptyVoiceResponse();
    }
    if (fireAt.isAfter(executionAt)) {
      log.info("scheduled_assignment attempt_exit planId={} studentId={} triggerSource=STUDENT_ENTRY reason=BEFORE_SCHEDULED_TIME fireAt={} executionAt={}",
          planId, studentId, fireAt, executionAt);
      return emptyVoiceResponse();
    }
    log.info("scheduled_assignment attempt_branch planId={} studentId={} planType={} triggerSource=STUDENT_ENTRY fireAt={} executionAt={}",
        plan.id, plan.studentId, plan.planType, fireAt, executionAt);
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

    log.warn("scheduled_assignment attempt_failed planId={} studentId={} planType={} triggerSource={} fireAt={} retryCount={} maxRetries={} errorType={} message={}",
        plan.id, plan.studentId, plan.planType, triggerSource, fireAt,
        run.retryCount, MAX_RETRIES, error.getClass().getSimpleName(), run.errorMessage);

    if (run.retryCount >= MAX_RETRIES && "ENABLED".equals(plan.status) &&
        plan.nextFireAt != null && plan.nextFireAt.equals(fireAt)) {
      log.warn("scheduled_assignment retries_exhausted planId={} studentId={} planType={} triggerSource={} fireAt={} retryCount={}",
          plan.id, plan.studentId, plan.planType, triggerSource, fireAt, run.retryCount);
      advance(plan, fireAt, executionAt);
    }
  }

  private void executeManualLocked(
      ScheduledAssignmentPlanEntity plan, Instant fireAt, Instant executionAt) {
    ScheduledAssignmentRunEntity run = prepareRun(plan.id, fireAt, "SCHEDULER", executionAt);
    if (isFinal(run)) {
      log.info("scheduled_assignment manual_exit planId={} studentId={} fireAt={} reason=RUN_ALREADY_FINAL runStatus={} skipReason={} assignmentId={}",
          plan.id, plan.studentId, fireAt, run.status, run.skipReason, run.assignmentId);
      advance(plan, fireAt, executionAt);
      return;
    }

    ScheduledAssignmentTemplateEntity template = templates.findById(plan.id)
        .orElseThrow(() -> new ApiExceptions.BadRequest("普通定时作业缺少任务模板"));
    Instant dueAt = dueAt(plan, template, executionAt);
    if ("SAME_DAY_AT".equals(template.duePolicy) &&
        dueAt != null && !dueAt.isAfter(executionAt)) {
      log.info("scheduled_assignment manual_skip planId={} studentId={} fireAt={} reason=MISSED_DUE_WINDOW dueAt={} executionAt={}",
          plan.id, plan.studentId, fireAt, dueAt, executionAt);
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

    log.info("scheduled_assignment manual_create_start planId={} studentId={} fireAt={} assignmentId={} subjectCode={} dueAt={}",
        plan.id, plan.studentId, fireAt, assignmentId, template.subjectCode, dueAt);
    AssignmentDtos.Response assignment =
        assignments.create(plan.familyId, plan.studentId, create);
    run.status = "SUCCESS";
    run.assignmentId = assignment.id();
    run.skipReason = "";
    run.errorMessage = "";
    run.finishedAt = executionAt;
    runs.save(run);
    log.info("scheduled_assignment manual_success planId={} studentId={} fireAt={} assignmentId={}",
        plan.id, plan.studentId, fireAt, assignment.id());
    advance(plan, fireAt, executionAt);
  }

  private VoiceMaterialDtos.AutoCreateResponse executeVoiceLocked(
      ScheduledAssignmentPlanEntity plan, Instant fireAt, String triggerSource,
      Instant executionAt) {
    ScheduledAssignmentRunEntity run = prepareRun(plan.id, fireAt, triggerSource, executionAt);
    if (isFinal(run)) {
      log.info("scheduled_assignment voice_exit planId={} studentId={} triggerSource={} fireAt={} reason=RUN_ALREADY_FINAL runStatus={} skipReason={} assignmentId={}",
          plan.id, plan.studentId, triggerSource, fireAt,
          run.status, run.skipReason, run.assignmentId);
      return emptyVoiceResponse();
    }

    log.info("scheduled_assignment voice_auto_create_start planId={} studentId={} triggerSource={} fireAt={}",
        plan.id, plan.studentId, triggerSource, fireAt);
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

    if (result.created()) {
      log.info("scheduled_assignment voice_success planId={} studentId={} triggerSource={} fireAt={} assignmentId={} packageId={}",
          plan.id, plan.studentId, triggerSource, fireAt,
          result.assignmentId(), result.packageId());
    } else {
      log.info("scheduled_assignment voice_skip planId={} studentId={} triggerSource={} fireAt={} reason={} assignmentId={} packageId={} businessDate={}",
          plan.id, plan.studentId, triggerSource, fireAt, run.skipReason,
          text(result.assignmentId()), text(result.packageId()), result.businessDate());
    }

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
      log.info("scheduled_assignment run_reuse planId={} fireAt={} triggerSource={} runId={} runStatus={} skipReason={} retryCount={}",
          planId, fireAt, triggerSource, existing.id, existing.status,
          existing.skipReason, existing.retryCount);
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
    ScheduledAssignmentRunEntity saved = runs.saveAndFlush(run);
    log.info("scheduled_assignment run_created planId={} fireAt={} triggerSource={} runId={}",
        planId, fireAt, triggerSource, saved.id);
    return saved;
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
    log.info("scheduled_assignment plan_advanced planId={} studentId={} planType={} firedAt={} nextFireAt={} status={}",
        plan.id, plan.studentId, plan.planType, fireAt, next, plan.status);
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
