package com.xiaoban.homework.scheduledassignment;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialAssignmentService;
import com.xiaoban.homework.voicematerial.VoiceMaterialDtos;
import java.time.DateTimeException;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ScheduledAssignmentService {
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");
  private static final DateTimeFormatter TIME_FORMAT = DateTimeFormatter.ofPattern("HH:mm");
  private static final int MAX_RETRIES = 3;

  private final ScheduledAssignmentPlanRepository plans;
  private final ScheduledAssignmentTemplateRepository templates;
  private final ScheduledAssignmentRunRepository runs;
  private final StudentService students;
  private final AssignmentService assignments;
  private final VoiceMaterialAssignmentService voiceAssignments;

  public ScheduledAssignmentService(
      ScheduledAssignmentPlanRepository plans,
      ScheduledAssignmentTemplateRepository templates,
      ScheduledAssignmentRunRepository runs,
      StudentService students,
      AssignmentService assignments,
      VoiceMaterialAssignmentService voiceAssignments) {
    this.plans = plans;
    this.templates = templates;
    this.runs = runs;
    this.students = students;
    this.assignments = assignments;
    this.voiceAssignments = voiceAssignments;
  }

  @Transactional(readOnly = true)
  public List<ScheduledAssignmentDtos.PlanResponse> list(UUID familyId, String studentId) {
    students.requireOwned(familyId, studentId);
    return plans.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, studentId)
        .stream().map(this::response).toList();
  }

  @Transactional(readOnly = true)
  public List<ScheduledAssignmentDtos.RunResponse> runs(UUID familyId, UUID planId) {
    ScheduledAssignmentPlanEntity plan = requireOwned(familyId, planId);
    return runs.findTop20ByPlanIdOrderByScheduledFireAtDesc(plan.id)
        .stream().map(this::runResponse).toList();
  }

  @Transactional
  public ScheduledAssignmentDtos.PlanResponse create(
      UUID familyId, String studentId, ScheduledAssignmentDtos.UpsertRequest input) {
    students.requireOwnedForUpdate(familyId, studentId);
    Instant now = Instant.now();
    ScheduledAssignmentPlanEntity plan = new ScheduledAssignmentPlanEntity();
    plan.id = UUID.randomUUID();
    plan.familyId = familyId;
    plan.studentId = studentId;
    plan.status = "ENABLED";
    applyPlanInput(plan, input.planType(), input.name(), input.scheduleType(),
        input.timeOfDay(), input.weekdays(), input.startDate(), input.endDate(), null);
    ensureVoicePlanUnique(plan);
    plan.createdAt = now;
    plan.updatedAt = now;
    plan.nextFireAt = nextFire(plan, now.minusMillis(1));
    if (plan.nextFireAt == null) {
      throw new ApiExceptions.BadRequest("计划没有可执行的未来时间");
    }
    plans.saveAndFlush(plan);
    saveTemplate(plan, input.template(), now);
    return response(plan);
  }

  @Transactional
  public ScheduledAssignmentDtos.PlanResponse update(
      UUID familyId, UUID planId, ScheduledAssignmentDtos.UpdateRequest input) {
    ScheduledAssignmentPlanEntity plan = requireOwnedForUpdate(familyId, planId);
    if (plan.version != input.version()) {
      throw new ApiExceptions.Conflict("定时计划已在其他设备更新，请刷新后重试");
    }
    students.requireOwnedForUpdate(familyId, plan.studentId);
    applyPlanInput(plan, input.planType(), input.name(), input.scheduleType(),
        input.timeOfDay(), input.weekdays(), input.startDate(), input.endDate(), plan.id);
    ensureVoicePlanUnique(plan);
    if ("ENDED".equals(plan.status)) plan.status = "ENABLED";
    plan.updatedAt = Instant.now();
    plan.nextFireAt = "ENABLED".equals(plan.status)
        ? nextFire(plan, Instant.now().minusMillis(1)) : null;
    if ("ENABLED".equals(plan.status) && plan.nextFireAt == null) {
      throw new ApiExceptions.BadRequest("计划没有可执行的未来时间");
    }
    plans.saveAndFlush(plan);
    saveTemplate(plan, input.template(), plan.updatedAt);
    return response(plan);
  }

  @Transactional
  public ScheduledAssignmentDtos.PlanResponse action(
      UUID familyId, UUID planId, ScheduledAssignmentDtos.ActionRequest input) {
    ScheduledAssignmentPlanEntity plan = requireOwnedForUpdate(familyId, planId);
    if (plan.version != input.version()) {
      throw new ApiExceptions.Conflict("定时计划已在其他设备更新，请刷新后重试");
    }
    String action = input.action().trim().toUpperCase(Locale.ROOT);
    if ("PAUSE".equals(action)) {
      plan.status = "PAUSED";
      plan.nextFireAt = null;
    } else if ("ENABLE".equals(action)) {
      plan.status = "ENABLED";
      plan.nextFireAt = nextFire(plan, Instant.now().minusMillis(1));
      if (plan.nextFireAt == null) plan.status = "ENDED";
    } else {
      throw new ApiExceptions.BadRequest("不支持的计划动作: " + input.action());
    }
    plan.updatedAt = Instant.now();
    return response(plans.saveAndFlush(plan));
  }

  @Transactional
  public void delete(UUID familyId, UUID planId) {
    ScheduledAssignmentPlanEntity plan = requireOwnedForUpdate(familyId, planId);
    plans.delete(plan);
    plans.flush();
  }

  @Transactional(readOnly = true)
  public List<UUID> duePlanIds(Instant now) {
    return plans.findByStatusAndNextFireAtLessThanEqualOrderByNextFireAtAsc("ENABLED", now)
        .stream().map(item -> item.id).toList();
  }

  @Transactional
  public void executeDuePlan(UUID planId, Instant now) {
    ScheduledAssignmentPlanEntity plan = plans.lockById(planId).orElse(null);
    if (plan == null || !"ENABLED".equals(plan.status) || plan.nextFireAt == null ||
        plan.nextFireAt.isAfter(now)) {
      return;
    }
    executePlan(plan, plan.nextFireAt, "SCHEDULER");
  }

  @Transactional
  public VoiceMaterialDtos.AutoCreateResponse autoCreateOnStudentEntry(
      UUID familyId, String studentId) {
    students.requireOwnedForUpdate(familyId, studentId);
    List<ScheduledAssignmentPlanEntity> voicePlans =
        plans.findByFamilyIdAndStudentIdAndPlanTypeOrderByCreatedAtDesc(
            familyId, studentId, "VOICE_MATERIAL_AUTO");
    if (voicePlans.isEmpty()) {
      return voiceAssignments.autoCreateNext(familyId, studentId);
    }

    ScheduledAssignmentPlanEntity eligible = null;
    Instant now = Instant.now();
    for (ScheduledAssignmentPlanEntity plan : voicePlans) {
      if (!"ENABLED".equals(plan.status) || plan.nextFireAt == null) continue;
      if (!plan.nextFireAt.isAfter(now)) {
        eligible = plans.lockById(plan.id).orElse(null);
        break;
      }
    }
    if (eligible == null || eligible.nextFireAt == null || eligible.nextFireAt.isAfter(now)) {
      return emptyVoiceResponse();
    }
    return executeVoicePlan(eligible, eligible.nextFireAt, "STUDENT_ENTRY");
  }

  private void executePlan(
      ScheduledAssignmentPlanEntity plan, Instant fireAt, String triggerSource) {
    if ("VOICE_MATERIAL_AUTO".equals(plan.planType)) {
      executeVoicePlan(plan, fireAt, triggerSource);
      return;
    }

    ScheduledAssignmentRunEntity run = prepareRun(plan.id, fireAt, triggerSource);
    if (isFinal(run)) {
      advance(plan, fireAt);
      return;
    }
    try {
      AssignmentDtos.Response assignment = createManualAssignment(plan, fireAt);
      run.status = "SUCCESS";
      run.assignmentId = assignment.id();
      run.skipReason = "";
      run.errorMessage = "";
      run.finishedAt = Instant.now();
      runs.save(run);
      advance(plan, fireAt);
    } catch (RuntimeException error) {
      failRun(plan, run, fireAt, error);
    }
  }

  private VoiceMaterialDtos.AutoCreateResponse executeVoicePlan(
      ScheduledAssignmentPlanEntity plan, Instant fireAt, String triggerSource) {
    ScheduledAssignmentRunEntity run = prepareRun(plan.id, fireAt, triggerSource);
    if (isFinal(run)) {
      advance(plan, fireAt);
      return emptyVoiceResponse();
    }
    try {
      VoiceMaterialDtos.AutoCreateResponse result =
          voiceAssignments.autoCreateNext(plan.familyId, plan.studentId);
      run.status = result.created() ? "SUCCESS" : "SKIPPED";
      run.assignmentId = blankToNull(result.assignmentId());
      run.skipReason = result.created() ? "" : voiceSkipReason(result);
      run.errorMessage = "";
      run.finishedAt = Instant.now();
      runs.save(run);
      advance(plan, fireAt);
      return result;
    } catch (RuntimeException error) {
      failRun(plan, run, fireAt, error);
      return emptyVoiceResponse();
    }
  }

  private ScheduledAssignmentRunEntity prepareRun(
      UUID planId, Instant fireAt, String triggerSource) {
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
    run.createdAt = Instant.now();
    run.finishedAt = null;
    return runs.saveAndFlush(run);
  }

  private boolean isFinal(ScheduledAssignmentRunEntity run) {
    return "SUCCESS".equals(run.status) || "SKIPPED".equals(run.status);
  }

  private void failRun(ScheduledAssignmentPlanEntity plan, ScheduledAssignmentRunEntity run,
      Instant fireAt, RuntimeException error) {
    run.status = "FAILED";
    run.retryCount++;
    String message = error.getMessage();
    run.errorMessage = message == null ? error.getClass().getSimpleName() :
        message.substring(0, Math.min(message.length(), 500));
    run.finishedAt = Instant.now();
    runs.save(run);
    if (run.retryCount >= MAX_RETRIES) advance(plan, fireAt);
  }

  private AssignmentDtos.Response createManualAssignment(
      ScheduledAssignmentPlanEntity plan, Instant fireAt) {
    ScheduledAssignmentTemplateEntity template = templates.findById(plan.id)
        .orElseThrow(() -> new ApiExceptions.BadRequest("普通定时作业缺少任务模板"));
    Instant dueAt = dueAt(plan, template, fireAt);
    String dueText = dueText(template);
    String assignmentId = "a-scheduled-" + plan.id + "-" + fireAt.toEpochMilli();
    AssignmentDtos.Create create = new AssignmentDtos.Create(
        assignmentId,
        template.subject,
        template.title,
        template.instruction,
        "",
        dueText,
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
    return assignments.create(plan.familyId, plan.studentId, create);
  }

  private Instant dueAt(ScheduledAssignmentPlanEntity plan,
      ScheduledAssignmentTemplateEntity template, Instant fireAt) {
    ZoneId zone = zone(plan.timezone);
    LocalDate date = fireAt.atZone(zone).toLocalDate();
    return switch (template.duePolicy) {
      case "SAME_DAY_AT" -> date.atTime(template.dueTime).atZone(zone).toInstant();
      case "NEXT_DAY_AT" -> date.plusDays(1).atTime(template.dueTime).atZone(zone).toInstant();
      case "AFTER_MINUTES" -> fireAt.plusSeconds((long) template.dueOffsetMinutes * 60L);
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

  private void advance(ScheduledAssignmentPlanEntity plan, Instant fireAt) {
    plan.lastFireAt = fireAt;
    Instant next = nextFire(plan, fireAt.plusMillis(1));
    plan.nextFireAt = next;
    if (next == null) plan.status = "ENDED";
    plan.updatedAt = Instant.now();
    plans.save(plan);
  }

  private Instant nextFire(ScheduledAssignmentPlanEntity plan, Instant after) {
    ZoneId zone = zone(plan.timezone);
    LocalDate cursor = after.atZone(zone).toLocalDate();
    if (cursor.isBefore(plan.startDate)) cursor = plan.startDate;
    for (int i = 0; i < 3660; i++) {
      LocalDate date = cursor.plusDays(i);
      if (plan.endDate != null && date.isAfter(plan.endDate)) return null;
      if (!eligibleDate(plan, date)) continue;
      Instant candidate = LocalDateTime.of(date, plan.scheduleTime).atZone(zone).toInstant();
      if (candidate.isAfter(after)) return candidate;
    }
    return null;
  }

  private boolean eligibleDate(ScheduledAssignmentPlanEntity plan, LocalDate date) {
    if (date.isBefore(plan.startDate)) return false;
    if ("ONCE".equals(plan.scheduleType)) return date.equals(plan.startDate);
    if ("DAILY".equals(plan.scheduleType)) return true;
    if ("WEEKDAYS".equals(plan.scheduleType)) {
      return date.getDayOfWeek() != DayOfWeek.SATURDAY &&
          date.getDayOfWeek() != DayOfWeek.SUNDAY;
    }
    return weekdaySet(plan.weekdays).contains(date.getDayOfWeek());
  }

  private void applyPlanInput(ScheduledAssignmentPlanEntity plan,
      String planType, String name, String scheduleType, String timeOfDay,
      List<String> weekdays, String startDate, String endDate, UUID selfId) {
    plan.planType = planType(planType);
    plan.name = name.trim();
    plan.scheduleType = scheduleType(scheduleType);
    plan.scheduleTime = time(timeOfDay, "创建时间");
    plan.weekdays = weekdays(weekdays, plan.scheduleType);
    plan.startDate = date(startDate, "开始日期");
    plan.endDate = nullableDate(endDate, "结束日期");
    if (plan.endDate != null && plan.endDate.isBefore(plan.startDate)) {
      throw new ApiExceptions.BadRequest("结束日期不能早于开始日期");
    }
    plan.timezone = BUSINESS_ZONE.getId();
  }

  private void saveTemplate(ScheduledAssignmentPlanEntity plan,
      ScheduledAssignmentDtos.TemplateInput input, Instant now) {
    if ("VOICE_MATERIAL_AUTO".equals(plan.planType)) {
      templates.findById(plan.id).ifPresent(templates::delete);
      return;
    }
    if (input == null) throw new ApiExceptions.BadRequest("普通定时作业必须填写任务模板");
    ScheduledAssignmentTemplateEntity template = templates.findById(plan.id)
        .orElseGet(ScheduledAssignmentTemplateEntity::new);
    if (template.planId == null) {
      template.planId = plan.id;
      template.createdAt = now;
    }
    template.assignmentType = assignmentType(input.assignmentType());
    template.subject = input.subject().trim();
    template.subjectCode = input.subjectCode().trim().toUpperCase(Locale.ROOT);
    template.title = input.title().trim();
    template.instruction = input.instruction().trim();
    template.expectedMinutes = expectedMinutes(input.expectedMinutes());
    template.duePolicy = duePolicy(input.duePolicy());
    template.dueTime = null;
    template.dueOffsetMinutes = null;
    if ("SAME_DAY_AT".equals(template.duePolicy) || "NEXT_DAY_AT".equals(template.duePolicy)) {
      template.dueTime = time(input.dueTime(), "截止时间");
    } else if ("AFTER_MINUTES".equals(template.duePolicy)) {
      int offset = input.dueOffsetMinutes() == null ? 0 : input.dueOffsetMinutes();
      if (offset < 1 || offset > 10080) {
        throw new ApiExceptions.BadRequest("创建后截止分钟数必须在 1 到 10080 之间");
      }
      template.dueOffsetMinutes = offset;
    }
    template.updatedAt = now;
    templates.saveAndFlush(template);
  }

  private void ensureVoicePlanUnique(ScheduledAssignmentPlanEntity plan) {
    if (!"VOICE_MATERIAL_AUTO".equals(plan.planType)) return;
    for (ScheduledAssignmentPlanEntity existing :
        plans.findByFamilyIdAndStudentIdAndPlanTypeOrderByCreatedAtDesc(
            plan.familyId, plan.studentId, "VOICE_MATERIAL_AUTO")) {
      if (!existing.id.equals(plan.id)) {
        throw new ApiExceptions.Conflict("同一学生只能配置一个语音自动创建计划");
      }
    }
  }

  private ScheduledAssignmentDtos.PlanResponse response(ScheduledAssignmentPlanEntity plan) {
    ScheduledAssignmentDtos.TemplateResponse template = templates.findById(plan.id)
        .map(this::templateResponse).orElse(null);
    return new ScheduledAssignmentDtos.PlanResponse(
        plan.id.toString(), plan.studentId, plan.planType, plan.name,
        plan.scheduleType, plan.scheduleTime.format(TIME_FORMAT),
        weekdayList(plan.weekdays), plan.startDate.toString(),
        plan.endDate == null ? "" : plan.endDate.toString(),
        plan.timezone, plan.status,
        epoch(plan.nextFireAt), epoch(plan.lastFireAt), template, plan.version);
  }

  private ScheduledAssignmentDtos.TemplateResponse templateResponse(
      ScheduledAssignmentTemplateEntity template) {
    return new ScheduledAssignmentDtos.TemplateResponse(
        template.assignmentType, template.subject, template.subjectCode,
        template.title, template.instruction, template.expectedMinutes,
        template.duePolicy,
        template.dueTime == null ? "" : template.dueTime.format(TIME_FORMAT),
        template.dueOffsetMinutes == null ? 0 : template.dueOffsetMinutes);
  }

  private ScheduledAssignmentDtos.RunResponse runResponse(ScheduledAssignmentRunEntity run) {
    return new ScheduledAssignmentDtos.RunResponse(
        run.id.toString(), epoch(run.scheduledFireAt), run.triggerSource, run.status,
        text(run.assignmentId), run.skipReason, run.errorMessage, run.retryCount,
        epoch(run.finishedAt));
  }

  private ScheduledAssignmentPlanEntity requireOwned(UUID familyId, UUID planId) {
    return plans.findByIdAndFamilyId(planId, familyId)
        .orElseThrow(() -> new ApiExceptions.NotFound("定时计划不存在"));
  }

  private ScheduledAssignmentPlanEntity requireOwnedForUpdate(UUID familyId, UUID planId) {
    ScheduledAssignmentPlanEntity plan = plans.lockById(planId)
        .orElseThrow(() -> new ApiExceptions.NotFound("定时计划不存在"));
    if (!familyId.equals(plan.familyId)) throw new ApiExceptions.NotFound("定时计划不存在");
    return plan;
  }

  private VoiceMaterialDtos.AutoCreateResponse emptyVoiceResponse() {
    return new VoiceMaterialDtos.AutoCreateResponse(
        false, LocalDate.now(BUSINESS_ZONE).toString(), "", "", null);
  }

  private String voiceSkipReason(VoiceMaterialDtos.AutoCreateResponse result) {
    if (result.assignment() != null) return "ACTIVE_TASK_EXISTS";
    if (!text(result.packageId()).isBlank() || !text(result.assignmentId()).isBlank()) {
      return "ALREADY_CREATED_TODAY";
    }
    return "NO_MATERIAL";
  }

  private String planType(String value) {
    String normalized = text(value).trim().toUpperCase(Locale.ROOT);
    if (!"MANUAL_ASSIGNMENT".equals(normalized) &&
        !"VOICE_MATERIAL_AUTO".equals(normalized)) {
      throw new ApiExceptions.BadRequest("不支持的计划类型: " + value);
    }
    return normalized;
  }

  private String scheduleType(String value) {
    String normalized = text(value).trim().toUpperCase(Locale.ROOT);
    if (!"ONCE".equals(normalized) && !"DAILY".equals(normalized) &&
        !"WEEKDAYS".equals(normalized) && !"WEEKLY".equals(normalized)) {
      throw new ApiExceptions.BadRequest("不支持的重复方式: " + value);
    }
    return normalized;
  }

  private String assignmentType(String value) {
    String normalized = text(value).trim().toUpperCase(Locale.ROOT);
    if (normalized.isBlank()) return "EXTRA";
    if (!"SCHOOL".equals(normalized) && !"EXTRA".equals(normalized)) {
      throw new ApiExceptions.BadRequest("不支持的作业类型: " + value);
    }
    return normalized;
  }

  private String duePolicy(String value) {
    String normalized = text(value).trim().toUpperCase(Locale.ROOT);
    if (!"SAME_DAY_AT".equals(normalized) && !"NEXT_DAY_AT".equals(normalized) &&
        !"AFTER_MINUTES".equals(normalized) && !"NONE".equals(normalized)) {
      throw new ApiExceptions.BadRequest("不支持的截止规则: " + value);
    }
    return normalized;
  }

  private int expectedMinutes(Integer value) {
    int normalized = value == null ? 20 : value;
    if (normalized < 1 || normalized > 240) {
      throw new ApiExceptions.BadRequest("预计用时必须在 1 到 240 分钟之间");
    }
    return normalized;
  }

  private String weekdays(List<String> values, String scheduleType) {
    if (!"WEEKLY".equals(scheduleType)) return "";
    Set<DayOfWeek> days = EnumSet.noneOf(DayOfWeek.class);
    if (values != null) {
      for (String value : values) {
        if (value == null || value.isBlank()) continue;
        try {
          days.add(DayOfWeek.valueOf(value.trim().toUpperCase(Locale.ROOT)));
        } catch (IllegalArgumentException error) {
          throw new ApiExceptions.BadRequest("无效的星期: " + value);
        }
      }
    }
    if (days.isEmpty()) throw new ApiExceptions.BadRequest("每周计划至少选择一天");
    List<String> ordered = new ArrayList<>();
    for (DayOfWeek day : DayOfWeek.values()) if (days.contains(day)) ordered.add(day.name());
    return String.join(",", ordered);
  }

  private Set<DayOfWeek> weekdaySet(String value) {
    Set<DayOfWeek> result = EnumSet.noneOf(DayOfWeek.class);
    if (value == null || value.isBlank()) return result;
    for (String raw : value.split(",")) result.add(DayOfWeek.valueOf(raw));
    return result;
  }

  private List<String> weekdayList(String value) {
    if (value == null || value.isBlank()) return List.of();
    return List.of(value.split(","));
  }

  private LocalTime time(String value, String label) {
    try {
      return LocalTime.parse(text(value).trim(), TIME_FORMAT);
    } catch (DateTimeParseException error) {
      throw new ApiExceptions.BadRequest(label + "格式必须为 HH:mm");
    }
  }

  private LocalDate date(String value, String label) {
    try {
      return LocalDate.parse(text(value).trim());
    } catch (DateTimeParseException error) {
      throw new ApiExceptions.BadRequest(label + "格式必须为 YYYY-MM-DD");
    }
  }

  private LocalDate nullableDate(String value, String label) {
    return value == null || value.isBlank() ? null : date(value, label);
  }

  private ZoneId zone(String value) {
    try {
      return ZoneId.of(value);
    } catch (DateTimeException error) {
      throw new ApiExceptions.BadRequest("无效的计划时区: " + value);
    }
  }

  private long epoch(Instant value) { return value == null ? 0L : value.toEpochMilli(); }
  private String text(String value) { return value == null ? "" : value; }
  private String blankToNull(String value) {
    String normalized = text(value).trim();
    return normalized.isBlank() ? null : normalized;
  }
}
