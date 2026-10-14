package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentRepository;
import com.xiaoban.homework.assignment.AssignmentResourceService;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VoiceMaterialAssignmentService {
  private static final Logger log = LoggerFactory.getLogger(VoiceMaterialAssignmentService.class);
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");

  private final VoiceMaterialPackageRepository packages;
  private final VoiceMaterialFileRepository files;
  private final VoiceMaterialTaskLinkRepository links;
  private final VoiceMaterialAutoCreateRecordRepository autoRecords;
  private final AssignmentRepository assignmentRepository;
  private final AssignmentService assignments;
  private final AssignmentResourceService assignmentResources;
  private final StudentService students;

  public VoiceMaterialAssignmentService(VoiceMaterialPackageRepository packages,
      VoiceMaterialFileRepository files,
      VoiceMaterialTaskLinkRepository links,
      VoiceMaterialAutoCreateRecordRepository autoRecords,
      AssignmentRepository assignmentRepository,
      AssignmentService assignments,
      AssignmentResourceService assignmentResources,
      StudentService students) {
    this.packages = packages;
    this.files = files;
    this.links = links;
    this.autoRecords = autoRecords;
    this.assignmentRepository = assignmentRepository;
    this.assignments = assignments;
    this.assignmentResources = assignmentResources;
    this.students = students;
  }

  /**
   * 批量删除语音任务（assignment.content_type = AUDIO_IMAGE）。
   *
   * <p>与单条删除 {@code DELETE /assignments/{id}} 的唯一行为差别是：这里允许删除「已完成」任务。
   * 完成态任务带着孩子的提交记录和照片，会被一并永久删除，所以前端必须二次确认
   * （输入确认词）才能提交这类 id。
   *
   * <p>刻意<b>不</b>清理 voice_material_task_link 与 voice_material_auto_create_record，
   * 与单条删除保持一致：
   * <ul>
   *   <li>task_link 保留 → 文件夹的「已使用次数」与最近关联任务仍能看到这次记录，
   *       历史显示为「任务已删除」（voice_material_e2e.py 对此有断言）。</li>
   *   <li>auto_create_record 保留 → 「每个自然日最多自动建一次任务」的限额不被绕过，
   *       否则删掉当天自动建出的任务后 App 会再补建一条。</li>
   * </ul>
   *
   * <p>素材目录与 media_asset 都不动——任务与素材各自独立引用，删任务不该动素材库。
   *
   * <p>校验阶段用 Optional 查找、不抛异常：本方法已在事务中，任何 @Transactional 方法抛异常
   * 都会把外层事务标记成 rollback-only，逐项容错就会变成整体失败。
   */
  @Transactional
  public VoiceMaterialDtos.BatchDeleteResponse batchDeleteTasks(UUID familyId, List<String> rawIds) {
    List<String> ids = normalizeDeleteIds(rawIds);
    List<VoiceMaterialDtos.BatchDeleteItem> results = new ArrayList<>();
    List<String> deletable = new ArrayList<>();

    for (String id : ids) {
      AssignmentEntity item = assignmentRepository.findById(id).orElse(null);
      if (item == null || !familyId.equals(item.familyId)) {
        results.add(new VoiceMaterialDtos.BatchDeleteItem(id, "", false, "语音任务不存在或无权访问"));
        continue;
      }
      if (!"AUDIO_IMAGE".equals(item.contentType)) {
        results.add(new VoiceMaterialDtos.BatchDeleteItem(
            id, label(item), false, "不是语音任务，已跳过"));
        continue;
      }
      deletable.add(id);
      results.add(new VoiceMaterialDtos.BatchDeleteItem(id, label(item), true, ""));
    }

    for (String id : deletable) {
      assignments.deleteAllowingCompleted(familyId, id);
    }
    if (!deletable.isEmpty()) {
      log.info("voice_material tasks_batch_deleted familyId={} requested={} deleted={}",
          familyId, ids.size(), deletable.size());
    }
    return VoiceMaterialDtos.BatchDeleteResponse.of(ids.size(), results);
  }

  private String label(AssignmentEntity item) {
    return item.title == null ? "" : item.title;
  }

  private List<String> normalizeDeleteIds(List<String> rawIds) {
    if (rawIds == null) return List.of();
    return rawIds.stream()
        .filter(Objects::nonNull)
        .map(String::trim)
        .filter(id -> !id.isBlank())
        .distinct()
        .toList();
  }

  @Transactional
  public VoiceMaterialDtos.CreateAssignmentResponse createManually(UUID familyId, UUID packageId) {
    String studentId = packages.findOwnedStudentId(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音文件夹不存在"));
    return createManually(familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            studentId, null, null, LocalDate.now(BUSINESS_ZONE).toString(), "", "", ""));
  }

  @Transactional
  public VoiceMaterialDtos.CreateAssignmentResponse createManually(
      UUID familyId, UUID packageId, VoiceMaterialDtos.CreateAssignmentRequest input) {
    String sourceStudentId = packages.findOwnedStudentId(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音文件夹不存在"));
    students.requireOwnedForUpdate(familyId, sourceStudentId);

    String targetStudentId = input.studentId().trim();
    students.requireOwnedForUpdate(familyId, targetStudentId);
    if (!sourceStudentId.equals(targetStudentId)) {
      throw new ApiExceptions.BadRequest("语音文件夹只能用于其所属学生创建任务");
    }

    VoiceMaterialPackageEntity item = packages.lockOwned(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音文件夹不存在"));

    String requestId = normalizeRequestId(input.requestId());
    log.info("voice_material manual_create_start studentId={} packageId={} requestIdPresent={}",
        targetStudentId, packageId, !requestId.isBlank());
    if (!requestId.isBlank()) {
      VoiceMaterialTaskLinkEntity previous =
          links.findByFamilyIdAndRequestId(familyId, requestId).orElse(null);
      if (previous != null) {
        if (!previous.packageId.equals(packageId) ||
            !previous.studentId.equals(targetStudentId)) {
          throw new ApiExceptions.Conflict("requestId 已用于其他语音任务创建请求");
        }
        AssignmentDtos.Response existing = loadAssignmentIfPresent(
            familyId, previous.assignmentId);
        log.info("voice_material manual_create_reused studentId={} packageId={} assignmentId={} requestIdPresent=true",
            targetStudentId, packageId, previous.assignmentId);
        return new VoiceMaterialDtos.CreateAssignmentResponse(
            false, previous.assignmentId, existing);
      }
    }

    if (!"READY".equals(item.status) && !"CONSUMED".equals(item.status)) {
      throw new ApiExceptions.BadRequest("当前文件夹不可用于创建任务");
    }

    String requestedSubjectCode = normalizeSubjectCode(input.subjectCode(), item.subjectCode);
    String requestedTitle = input.title() == null ? "" : input.title().trim();
    String requestedInstruction =
        input.instruction() == null ? "" : input.instruction().trim();
    AssignmentDtos.Response assignment = createFromFolder(
        familyId, item, targetStudentId, requestedSubjectCode,
        input.expectedMinutes() == null ? item.expectedMinutes : input.expectedMinutes(),
        taskDate(input.taskDate()),
        LocalDate.now(BUSINESS_ZONE),
        requestedTitle,
        requestedInstruction,
        requestId,
        "MANUAL");
    log.info("voice_material manual_create_success studentId={} packageId={} assignmentId={} subjectCode={} requestIdPresent={}",
        targetStudentId, packageId, assignment.id(), requestedSubjectCode, !requestId.isBlank());
    return new VoiceMaterialDtos.CreateAssignmentResponse(
        true, assignment.id(), assignment);
  }

  @Transactional
  public VoiceMaterialDtos.AutoCreateResponse autoCreateNext(UUID familyId, String studentId) {
    return autoCreateNext(familyId, studentId, "");
  }

  @Transactional
  public VoiceMaterialDtos.AutoCreateResponse autoCreateNext(
      UUID familyId, String studentId, String subjectCode) {
    students.requireOwnedForUpdate(familyId, studentId);
    String requestedSubjectCode = normalizeAutoSubjectCode(subjectCode);
    LocalDate businessDate = LocalDate.now(BUSINESS_ZONE);
    log.info("voice_material auto_create_start studentId={} subjectCode={} businessDate={}",
        studentId, requestedSubjectCode, businessDate);

    AssignmentDtos.Response current =
        assignments.findFirstVoiceMaterialTaskForDate(familyId, studentId, businessDate);
    if (current != null) {
      String packageId = links.findByFamilyIdAndAssignmentId(familyId, current.id())
          .map(link -> link.packageId.toString())
          .orElse("");
      log.info("voice_material auto_create_exit studentId={} businessDate={} reason=ACTIVE_TASK_EXISTS assignmentId={} packageId={} status={} taskDate={}",
          studentId, businessDate, current.id(), packageId, current.status(), current.taskDate());
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), packageId, current.id(), current, false);
    }

    // 顺延必须排在「今天已自动创建过」之前：今天那条记录很可能就是这条任务自己创建时写下的，
    // 只要任务还没做完，就应该把它挪到今天，而不是让记录把它永远挡在昨天。
    CarryOver carryOver = findCarryOver(familyId, studentId, businessDate);
    if (carryOver != null) {
      AssignmentDtos.Response moved = assignments.carryOverToBusinessDate(
          familyId, carryOver.assignmentId, businessDate, carryOver.materialTitle);
      recordAutoCreate(familyId, studentId, businessDate, carryOver.packageId,
          carryOver.assignmentId);
      log.info("voice_material auto_create_carried_over studentId={} businessDate={} assignmentId={} packageId={} fromDate={} status={}",
          studentId, businessDate, carryOver.assignmentId, carryOver.packageId,
          carryOver.taskDate, carryOver.status);
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), carryOver.packageId.toString(),
          carryOver.assignmentId, moved, true);
    }

    VoiceMaterialAutoCreateRecordEntity todayRecord =
        autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
            familyId, studentId, businessDate).orElse(null);
    if (todayRecord != null) {
      log.info("voice_material auto_create_exit studentId={} businessDate={} reason=ALREADY_CREATED_TODAY assignmentId={} packageId={} recordId={}",
          studentId, businessDate, todayRecord.assignmentId, todayRecord.packageId, todayRecord.id);
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), todayRecord.packageId.toString(),
          todayRecord.assignmentId, null, false);
    }

    VoiceMaterialPackageEntity item = chooseAutoFolder(familyId, studentId, requestedSubjectCode);
    if (item == null) {
      log.info("voice_material auto_create_exit studentId={} subjectCode={} businessDate={} reason=NO_MATERIAL",
          studentId, requestedSubjectCode, businessDate);
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), "", "", null, false);
    }

    log.info("voice_material auto_create_package_selected studentId={} businessDate={} packageId={} subjectCode={} status={}",
        studentId, businessDate, item.id, item.subjectCode, item.status);

    item = packages.lockOwned(familyId, item.id)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音文件夹不存在"));
    AssignmentDtos.Response assignment = createFromFolder(
        familyId, item, item.studentId, item.subjectCode, item.expectedMinutes, businessDate,
        businessDate,
        "", "", "", "AUTO");

    recordAutoCreate(familyId, studentId, businessDate, item.id, assignment.id());

    log.info("voice_material auto_create_success studentId={} businessDate={} packageId={} assignmentId={}",
        studentId, businessDate, item.id, assignment.id());
    return new VoiceMaterialDtos.AutoCreateResponse(
        true, businessDate.toString(), item.id.toString(),
        assignment.id(), assignment, false);
  }

  /**
   * 找准这条要顺延的任务：最新一条「自动创建」产生、还没被孩子交出去、且日期早于今天的语音任务。
   *
   * <p>只认 {@code create_mode = AUTO} 的任务。家长手工建的任务（MANUAL）带着家长自己选定的日期，
   * 迁移前的历史任务（LEGACY）语义不明，两者都不能被系统悄悄挪走——所以它们既不参与顺延，
   * 也不会挡住今天的自动创建。素材目录被删除后 link 会随外键级联消失，那条遗留任务同样不再参与。
   *
   * <p>link 按创建时间倒序扫描，因此命中的是最新那条；孩子已经交出去的历史任务会被跳过，
   * 不会把早该翻篇的作业又拉回今天。
   */
  private CarryOver findCarryOver(UUID familyId, String studentId, LocalDate businessDate) {
    for (VoiceMaterialTaskLinkEntity link :
        links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, studentId)) {
      if (!"AUTO".equals(link.createMode)) continue;
      if (link.packageId == null) continue;
      AssignmentEntity item = assignmentRepository.findById(link.assignmentId).orElse(null);
      if (item == null || !familyId.equals(item.familyId)) continue;
      if (!"AUDIO_IMAGE".equals(item.contentType)) continue;
      if (item.taskDate == null || !item.taskDate.isBefore(businessDate)) continue;
      if (isSettled(item.status)) continue;
      String materialTitle = packages.findById(link.packageId)
          .map(folder -> folder.title).orElse(null);
      return new CarryOver(item.id, link.packageId, item.taskDate, item.status, materialTitle);
    }
    return null;
  }

  /**
   * 孩子已经把这份交出去了（待提交 / 已提交 / 已完成）就不再顺延——他昨天做完了，
   * 今天应该拿到新的一份。其余状态（未开始 / 进行中 / 暂停 / 待订正 / 已逾期）都算还没做完。
   */
  private static boolean isSettled(String status) {
    return "READY_TO_SUBMIT".equals(status)
        || "SUBMITTED".equals(status)
        || "COMPLETED".equals(status);
  }

  /**
   * 记录「这个业务日的自动额度已经被用掉了」。
   *
   * <p>顺延同样要写一条今天的记录：否则孩子在今天把顺延来的任务做掉之后，
   * 同一天再进 App 又会立刻被塞一份新任务。
   *
   * <p>写之前必须先查：这条任务很可能就是今天自动建出来的（家长随后把日期改早了），
   * 那样今天的记录早就存在；直接 insert 会撞上
   * {@code uq_voice_material_auto_daily (family_id, student_id, business_date)}，
   * 把整次自动创建拖成 500。既有的记录一律不覆盖——它记的是「当天已用过额度」这个事实。
   *
   * <p>同一学生的并发自动创建由 {@code students.requireOwnedForUpdate} 的 SELECT FOR UPDATE 串行化，
   * 所以「先查后插」在这里不会和别的请求交错。
   */
  private void recordAutoCreate(UUID familyId, String studentId, LocalDate businessDate,
      UUID packageId, String assignmentId) {
    if (autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        familyId, studentId, businessDate).isPresent()) {
      log.info("voice_material auto_create_record_reused studentId={} businessDate={} assignmentId={}",
          studentId, businessDate, assignmentId);
      return;
    }
    VoiceMaterialAutoCreateRecordEntity record = new VoiceMaterialAutoCreateRecordEntity();
    record.id = UUID.randomUUID();
    record.familyId = familyId;
    record.studentId = studentId;
    record.businessDate = businessDate;
    record.packageId = packageId;
    record.assignmentId = assignmentId;
    record.createdAt = Instant.now();
    autoRecords.saveAndFlush(record);
  }

  private record CarryOver(String assignmentId, UUID packageId, LocalDate taskDate,
      String status, String materialTitle) {}

  private VoiceMaterialPackageEntity chooseAutoFolder(
      UUID familyId, String studentId, String subjectCode) {
    List<VoiceMaterialPackageEntity> candidates =
        packages.findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
            familyId, studentId).stream()
            .filter(item -> "READY".equals(item.status) || "CONSUMED".equals(item.status))
            .filter(item -> subjectCode.isBlank() || subjectCode.equals(item.subjectCode))
            .toList();
    if (candidates.isEmpty()) {
      log.info("voice_material auto_folder_candidates studentId={} candidateCount=0", studentId);
      return null;
    }
    log.info("voice_material auto_folder_candidates studentId={} candidateCount={}",
        studentId, candidates.size());

    Map<UUID, Long> usageCount = new HashMap<>();
    Map<UUID, Instant> lastUsedAt = new HashMap<>();
    for (VoiceMaterialTaskLinkEntity link :
        links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, studentId)) {
      usageCount.merge(link.packageId, 1L, Long::sum);
      lastUsedAt.putIfAbsent(link.packageId, link.createdAt);
    }

    VoiceMaterialPackageEntity selected = candidates.stream()
        .min(Comparator
            .comparingLong((VoiceMaterialPackageEntity item) ->
                usageCount.getOrDefault(item.id, 0L))
            .thenComparing(item ->
                lastUsedAt.getOrDefault(item.id, Instant.EPOCH))
            .thenComparing(item -> item.directoryName)
            .thenComparing(item -> item.createdAt)
            .thenComparing(item -> item.id))
        .orElse(null);
    if (selected != null) {
      log.info("voice_material auto_folder_selected studentId={} packageId={} usageCount={} lastUsedAt={}",
          studentId, selected.id, usageCount.getOrDefault(selected.id, 0L),
          lastUsedAt.getOrDefault(selected.id, Instant.EPOCH));
    }
    return selected;
  }

  private AssignmentDtos.Response createFromFolder(UUID familyId,
      VoiceMaterialPackageEntity item, String targetStudentId, String subjectCode,
      int expectedMinutes,
      LocalDate taskDate, LocalDate businessDate,
      String requestedTitle, String requestedInstruction, String requestId,
      String createMode) {
    String assignmentId = "a-voice-" + UUID.randomUUID();

    String title = requestedTitle == null || requestedTitle.isBlank()
        ? assignments.nextVoiceMaterialTaskTitle(
            familyId, targetStudentId, subjectCode, businessDate, item.title)
        : requestedTitle.trim();

    AssignmentDtos.Create create = new AssignmentDtos.Create(
        assignmentId,
        subjectDisplay(subjectCode),
        title,
        requestedInstruction == null || requestedInstruction.isBlank()
            ? "请听语音并结合图片完成任务。"
            : requestedInstruction.trim(),
        "",
        taskDate.toString(),
        item.assignmentType,
        subjectCode,
        "AUDIO_IMAGE",
        "NOT_STARTED",
        "语音素材库",
        item.directoryName,
        expectedMinutes,
        0L,
        0L,
        0L,
        "");

    AssignmentDtos.Response assignment =
        assignments.create(familyId, targetStudentId, create);

    List<VoiceMaterialFileEntity> packageFiles =
        files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
            familyId, item.id);
    List<AssignmentResourceService.AssetLink> resourceLinks = new ArrayList<>();
    for (VoiceMaterialFileEntity file : packageFiles) {
      resourceLinks.add(new AssignmentResourceService.AssetLink(
          file.resourceType, file.assetId, file.sortOrder, 0L,
          file.relativeName, contentType(file.resourceType, file.relativeName)));
    }
    assignmentResources.linkAssets(familyId, assignment.id(), resourceLinks);

    VoiceMaterialTaskLinkEntity link = new VoiceMaterialTaskLinkEntity();
    link.id = UUID.randomUUID().toString();
    link.familyId = familyId;
    link.studentId = targetStudentId;
    link.packageId = item.id;
    link.assignmentId = assignment.id();
    link.assignmentTitle = assignment.title();
    link.createMode = createMode;
    link.requestId = requestId.isBlank() ? null : requestId;
    link.createdAt = Instant.now();
    links.saveAndFlush(link);

    if ("CONSUMED".equals(item.status)) {
      item.status = "READY";
      item.updatedAt = Instant.now();
      packages.save(item);
    }
    return assignment;
  }

  private String normalizeAutoSubjectCode(String subjectCode) {
    String value = subjectCode == null ? "" : subjectCode.trim().toUpperCase();
    if (value.isBlank()) return "";
    if ("CHINESE".equals(value) || "MATH".equals(value) ||
        "ENGLISH".equals(value) || "OTHER".equals(value)) {
      return value;
    }
    throw new ApiExceptions.BadRequest("不支持的科目: " + subjectCode);
  }

  private String normalizeRequestId(String requestId) {
    return requestId == null ? "" : requestId.trim();
  }

  private String normalizeSubjectCode(String requested, String fallback) {
    String value = requested == null ? "" : requested.trim().toUpperCase();
    if ("CHINESE".equals(value) || "MATH".equals(value) ||
        "ENGLISH".equals(value) || "OTHER".equals(value)) {
      return value;
    }
    return fallback;
  }

  private LocalDate taskDate(String value) {
    if (value == null || value.isBlank()) return LocalDate.now(BUSINESS_ZONE);
    try {
      return LocalDate.parse(value.trim());
    } catch (java.time.format.DateTimeParseException error) {
      throw new ApiExceptions.BadRequest("任务日期格式应为 YYYY-MM-DD");
    }
  }

  private AssignmentDtos.Response loadAssignmentIfPresent(UUID familyId, String assignmentId) {
    if (assignmentId == null || assignmentId.isBlank()) return null;
    try {
      return assignments.get(familyId, assignmentId);
    } catch (ApiExceptions.NotFound missing) {
      return null;
    }
  }

  private String contentType(String resourceType, String fileName) {
    String lower = fileName == null ? "" : fileName.toLowerCase();
    if ("AUDIO".equals(resourceType)) {
      if (lower.endsWith(".m4a")) return "audio/mp4";
      if (lower.endsWith(".wav")) return "audio/wav";
      return "audio/mpeg";
    }
    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".webp")) return "image/webp";
    if (lower.endsWith(".heic")) return "image/heic";
    return "image/jpeg";
  }

  private String subjectDisplay(String subjectCode) {
    return switch (subjectCode) {
      case "CHINESE" -> "语文";
      case "MATH" -> "数学";
      case "ENGLISH" -> "英语";
      default -> "其他";
    };
  }
}
