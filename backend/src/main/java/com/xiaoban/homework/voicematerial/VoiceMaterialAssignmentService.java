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
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class VoiceMaterialAssignmentService {
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");

  private final VoiceMaterialPackageRepository packages;
  private final VoiceMaterialFileRepository files;
  private final VoiceMaterialAutoCreateRecordRepository autoRecords;
  private final AssignmentService assignments;
  private final AssignmentResourceService assignmentResources;
  private final StudentService students;

  public VoiceMaterialAssignmentService(VoiceMaterialPackageRepository packages,
      VoiceMaterialFileRepository files,
      VoiceMaterialAutoCreateRecordRepository autoRecords,
      AssignmentService assignments,
      AssignmentResourceService assignmentResources,
      StudentService students) {
    this.packages = packages;
    this.files = files;
    this.autoRecords = autoRecords;
    this.assignments = assignments;
    this.assignmentResources = assignmentResources;
    this.students = students;
  }

  @Transactional
  public VoiceMaterialDtos.CreateAssignmentResponse createManually(
      UUID familyId, UUID packageId, VoiceMaterialDtos.CreateAssignmentRequest input) {
    String studentId = packages.findOwnedStudentId(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材目录不存在"));
    students.requireOwnedForUpdate(familyId, studentId);
    String targetStudentId = input.studentId().trim();
    students.requireOwnedForUpdate(familyId, targetStudentId);
    VoiceMaterialPackageEntity item = packages.lockOwned(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材目录不存在"));

    AssignmentDtos.Response existing = loadAssignmentIfPresent(
        familyId, item.consumedAssignmentId);
    if (existing != null) {
      return new VoiceMaterialDtos.CreateAssignmentResponse(
          false, existing.id(), existing);
    }
    if (!"READY".equals(item.status) && !"CONSUMED".equals(item.status)) {
      throw new ApiExceptions.BadRequest("当前目录还没有准备好，不能生成任务");
    }

    AssignmentDtos.Response assignment = consumeLocked(
        familyId, item, targetStudentId,
        input.expectedMinutes() == null ? item.expectedMinutes : input.expectedMinutes(),
        resolveDueAt(input.dueAtEpochMs(), item.dueAt),
        input.dueText() == null ? "" : input.dueText().trim(),
        LocalDate.now(BUSINESS_ZONE));
    return new VoiceMaterialDtos.CreateAssignmentResponse(
        true, assignment.id(), assignment);
  }

  @Transactional
  public VoiceMaterialDtos.AutoCreateResponse autoCreateNext(UUID familyId, String studentId) {
    students.requireOwnedForUpdate(familyId, studentId);
    LocalDate businessDate = LocalDate.now(BUSINESS_ZONE);

    AssignmentDtos.Response current = assignments.findFirstVoiceMaterialTask(familyId, studentId);
    if (current != null) {
      String packageId = packages
          .findByFamilyIdAndStudentIdAndConsumedAssignmentId(familyId, studentId, current.id())
          .map(item -> item.id.toString())
          .orElse("");
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), packageId, current.id(), current);
    }

    List<VoiceMaterialPackageEntity> available =
        packages.lockNextAvailableForAutoCreate(familyId, studentId, PageRequest.of(0, 1));
    if (available.isEmpty()) {
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), "", "", null);
    }

    VoiceMaterialPackageEntity item = available.get(0);
    Instant dailyDueAt = item.dueAt == null
        ? businessDate.atTime(LocalTime.of(23, 59)).atZone(BUSINESS_ZONE).toInstant()
        : null;
    AssignmentDtos.Response assignment = consumeLocked(
        familyId, item, item.studentId, item.expectedMinutes, dailyDueAt,
        item.dueAt == null ? "今天" : "", businessDate);

    VoiceMaterialAutoCreateRecordEntity record =
        autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
            familyId, studentId, businessDate).orElseGet(VoiceMaterialAutoCreateRecordEntity::new);
    if (record.id == null) record.id = UUID.randomUUID();
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

  private AssignmentDtos.Response consumeLocked(UUID familyId,
      VoiceMaterialPackageEntity item, String targetStudentId, int expectedMinutes,
      Instant dueAtOverride, String dueTextOverride, LocalDate businessDate) {
    String assignmentId = "a-voicepkg-" + item.id;
    Long dueAtEpochMs = null;
    if (dueAtOverride != null) dueAtEpochMs = Long.valueOf(dueAtOverride.toEpochMilli());
    else if (item.dueAt != null) dueAtEpochMs = Long.valueOf(item.dueAt.toEpochMilli());

    AssignmentDtos.Create create = new AssignmentDtos.Create(
        assignmentId,
        subjectDisplay(item.subjectCode),
        assignments.nextVoiceMaterialTaskTitle(familyId, targetStudentId, item.subjectCode, businessDate),
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
    List<AssignmentResourceService.AssetLink> links = new ArrayList<>();
    for (VoiceMaterialFileEntity file : packageFiles) {
      links.add(new AssignmentResourceService.AssetLink(
          file.resourceType, file.assetId, file.sortOrder, 0L,
          file.relativeName, contentType(file.resourceType, file.relativeName)));
    }
    assignmentResources.linkAssets(familyId, assignment.id(), links);

    item.status = "CONSUMED";
    item.consumedAssignmentId = assignment.id();
    item.consumedAt = Instant.now();
    item.updatedAt = Instant.now();
    item.errorMessage = "";
    packages.save(item);
    return assignment;
  }

  private Instant resolveDueAt(Long requestedEpochMs, Instant fallback) {
    if (requestedEpochMs != null && requestedEpochMs > 0) return Instant.ofEpochMilli(requestedEpochMs);
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
