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
      UUID familyId, UUID packageId) {
    VoiceMaterialPackageEntity item = packages.lockOwned(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材目录不存在"));
    if ("CONSUMED".equals(item.status)) {
      AssignmentDtos.Response existing = loadAssignmentIfPresent(
          familyId, item.consumedAssignmentId);
      return new VoiceMaterialDtos.CreateAssignmentResponse(
          false, item.consumedAssignmentId, existing);
    }
    if (!"READY".equals(item.status)) {
      throw new ApiExceptions.BadRequest("只有可创建的语音素材目录才能生成任务");
    }

    AssignmentDtos.Response assignment = consumeLocked(familyId, item, null, "");
    return new VoiceMaterialDtos.CreateAssignmentResponse(
        true, assignment.id(), assignment);
  }

  @Transactional
  public VoiceMaterialDtos.AutoCreateResponse autoCreateNext(UUID familyId, String studentId) {
    students.requireOwnedForUpdate(familyId, studentId);
    LocalDate businessDate = LocalDate.now(BUSINESS_ZONE);

    VoiceMaterialAutoCreateRecordEntity existing =
        autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
            familyId, studentId, businessDate).orElse(null);
    if (existing != null) {
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), existing.packageId.toString(),
          existing.assignmentId, loadAssignmentIfPresent(familyId, existing.assignmentId));
    }

    List<VoiceMaterialPackageEntity> ready =
        packages.lockNextReady(familyId, studentId, PageRequest.of(0, 1));
    if (ready.isEmpty()) {
      return new VoiceMaterialDtos.AutoCreateResponse(
          false, businessDate.toString(), "", "", null);
    }

    VoiceMaterialPackageEntity item = ready.get(0);
    Instant dailyDueAt = item.dueAt == null
        ? businessDate.atTime(LocalTime.of(23, 59)).atZone(BUSINESS_ZONE).toInstant()
        : null;
    AssignmentDtos.Response assignment = consumeLocked(
        familyId, item, dailyDueAt, item.dueAt == null ? "今天" : "");

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

  private AssignmentDtos.Response consumeLocked(UUID familyId,
      VoiceMaterialPackageEntity item, Instant dueAtOverride, String dueTextOverride) {
    String assignmentId = "a-voicepkg-" + item.id;
    AssignmentDtos.Create create = new AssignmentDtos.Create(
        assignmentId,
        subjectDisplay(item.subjectCode),
        item.title,
        "请听语音并结合图片完成任务。",
        "",
        dueTextOverride,
        item.assignmentType,
        item.subjectCode,
        "AUDIO_IMAGE",
        dueAtOverride != null ? dueAtOverride.toEpochMilli()
            : (item.dueAt == null ? null : item.dueAt.toEpochMilli()),
        BUSINESS_ZONE.getId(),
        "NOT_STARTED",
        "语音素材库",
        item.directoryName,
        item.expectedMinutes,
        0L,
        0L,
        0L,
        "");

    AssignmentDtos.Response assignment =
        assignments.create(familyId, item.studentId, create);

    List<VoiceMaterialFileEntity> packageFiles =
        files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
            familyId, item.id);
    List<AssignmentResourceService.AssetLink> links = new ArrayList<>();
    for (VoiceMaterialFileEntity file : packageFiles) {
      links.add(new AssignmentResourceService.AssetLink(
          file.resourceType, file.assetId, file.sortOrder, 0L));
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

  private AssignmentDtos.Response loadAssignmentIfPresent(UUID familyId, String assignmentId) {
    if (assignmentId == null || assignmentId.isBlank()) return null;
    try {
      return assignments.get(familyId, assignmentId);
    } catch (ApiExceptions.NotFound missing) {
      return null;
    }
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
