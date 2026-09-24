package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentResourceService;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VoiceMaterialAssignmentService {
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");

  private final VoiceMaterialPackageRepository packages;
  private final VoiceMaterialFileRepository files;
  private final VoiceMaterialTaskLinkRepository links;
  private final VoiceMaterialAutoCreateRecordRepository autoRecords;
  private final AssignmentService assignments;
  private final AssignmentResourceService assignmentResources;
  private final StudentService students;

  public VoiceMaterialAssignmentService(VoiceMaterialPackageRepository packages,
      VoiceMaterialFileRepository files,
      VoiceMaterialTaskLinkRepository links,
      VoiceMaterialAutoCreateRecordRepository autoRecords,
      AssignmentService assignments,
      AssignmentResourceService assignmentResources,
      StudentService students) {
    this.packages = packages;
    this.files = files;
    this.links = links;
    this.autoRecords = autoRecords;
    this.assignments = assignments;
    this.assignmentResources = assignmentResources;
    this.students = students;
  }

  @Transactional
  public VoiceMaterialDtos.CreateAssignmentResponse createManually(UUID familyId, UUID packageId) {
    String studentId = packages.findOwnedStudentId(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音文件夹不存在"));
    return createManually(familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            studentId, null, 0L, "", "", ""));
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
        return new VoiceMaterialDtos.CreateAssignmentResponse(
            false, previous.assignmentId, existing);
      }
    }

    if (!"READY".equals(item.status) && !"CONSUMED".equals(item.status)) {
      throw new ApiExceptions.BadRequest("当前文件夹不可用于创建任务");
    }

    String requestedTitle = input.title() == null ? "" : input.title().trim();
    AssignmentDtos.Response assignment = createFromFolder(
        familyId, item, targetStudentId,
        input.expectedMinutes() == null ? item.expectedMinutes : input.expectedMinutes(),
        resolveDueAt(input.dueAtEpochMs(), item.dueAt),
        input.dueText() == null ? "" : input.dueText().trim(),
        LocalDate.now(BUSINESS_ZONE),
        requestedTitle,
        requestId,
        "MANUAL");
    return new VoiceMaterialDtos.CreateAssignmentResponse(
        true, assignment.id(), assignment);
  }

  @Transactional
  public VoiceMaterialDtos.AutoCreateResponse autoCreateNext(UUID familyId, String studentId) {
    students.requireOwnedForUpdate(familyId, studentId);
    LocalDate businessDate = LocalDate.now(BUSINESS_ZONE);

    AssignmentDtos.Response current =
        assignments.findFirstVoiceMaterialTask(familyId, studentId);
    if (current != null) {
      String packageId = links.findByFamilyIdAndAssignmentId(familyId, current.id())
          .map(link -> link.packageId.toString())
          .orElse("");
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), packageId, current.id(), current);
    }

    VoiceMaterialAutoCreateRecordEntity todayRecord =
        autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
            familyId, studentId, businessDate).orElse(null);
    if (todayRecord != null) {
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), todayRecord.packageId.toString(),
          todayRecord.assignmentId, null);
    }

    VoiceMaterialPackageEntity item = chooseAutoFolder(familyId, studentId);
    if (item == null) {
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), "", "", null);
    }

    item = packages.lockOwned(familyId, item.id)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音文件夹不存在"));
    Instant dailyDueAt = item.dueAt == null
        ? businessDate.atTime(LocalTime.of(23, 59)).atZone(BUSINESS_ZONE).toInstant()
        : null;
    AssignmentDtos.Response assignment = createFromFolder(
        familyId, item, item.studentId, item.expectedMinutes, dailyDueAt,
        item.dueAt == null ? "今天" : "", businessDate,
        "", "", "AUTO");

    VoiceMaterialAutoCreateRecordEntity record = new VoiceMaterialAutoCreateRecordEntity();
    record.id = UUID.randomUUID();
    record.familyId = familyId;
    record.studentId = studentId;
    record.businessDate = businessDate;
    record.packageId = item.id;
    record.assignmentId = assignment.id();
    record.createdAt = Instant.now();
    autoRecords.saveAndFlush(record);

    return new VoiceMaterialDtos.AutoCreateResponse(
        true, businessDate.toString(), item.id.toString(),
        assignment.id(), assignment);
  }

  private VoiceMaterialPackageEntity chooseAutoFolder(UUID familyId, String studentId) {
    List<VoiceMaterialPackageEntity> candidates =
        packages.findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
            familyId, studentId).stream()
            .filter(item -> "READY".equals(item.status) || "CONSUMED".equals(item.status))
            .toList();
    if (candidates.isEmpty()) return null;

    Map<UUID, Long> usageCount = new HashMap<>();
    Map<UUID, Instant> lastUsedAt = new HashMap<>();
    for (VoiceMaterialTaskLinkEntity link :
        links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, studentId)) {
      usageCount.merge(link.packageId, 1L, Long::sum);
      lastUsedAt.putIfAbsent(link.packageId, link.createdAt);
    }

    return candidates.stream()
        .min(Comparator
            .comparingLong((VoiceMaterialPackageEntity item) ->
                usageCount.getOrDefault(item.id, 0L))
            .thenComparing(item ->
                lastUsedAt.getOrDefault(item.id, Instant.EPOCH))
            .thenComparing(item -> item.directoryName)
            .thenComparing(item -> item.createdAt)
            .thenComparing(item -> item.id))
        .orElse(null);
  }

  private AssignmentDtos.Response createFromFolder(UUID familyId,
      VoiceMaterialPackageEntity item, String targetStudentId, int expectedMinutes,
      Instant dueAtOverride, String dueTextOverride, LocalDate businessDate,
      String requestedTitle, String requestId, String createMode) {
    String assignmentId = "a-voice-" + UUID.randomUUID();
    Long dueAtEpochMs = null;
    if (dueAtOverride != null) dueAtEpochMs = dueAtOverride.toEpochMilli();
    else if (item.dueAt != null) dueAtEpochMs = item.dueAt.toEpochMilli();

    String title = requestedTitle == null || requestedTitle.isBlank()
        ? assignments.nextVoiceMaterialTaskTitle(
            familyId, targetStudentId, item.subjectCode, businessDate)
        : requestedTitle.trim();

    AssignmentDtos.Create create = new AssignmentDtos.Create(
        assignmentId,
        subjectDisplay(item.subjectCode),
        title,
        "请听语音并结合图片完成任务。",
        "",
        dueTextOverride,
        item.assignmentType,
        item.subjectCode,
        "AUDIO_IMAGE",
        dueAtEpochMs,
        BUSINESS_ZONE.getId(),
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

  private String normalizeRequestId(String requestId) {
    return requestId == null ? "" : requestId.trim();
  }

  private Instant resolveDueAt(Long requestedEpochMs, Instant fallback) {
    if (requestedEpochMs != null && requestedEpochMs > 0) {
      return Instant.ofEpochMilli(requestedEpochMs);
    }
    return fallback;
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
