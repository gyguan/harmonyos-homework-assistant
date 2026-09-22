package com.xiaoban.homework.voicematerial;

import com.xiaoban.homework.assignment.VoiceMediaPolicy;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.media.MediaAssetEntity;
import com.xiaoban.homework.media.MediaAssetRepository;
import com.xiaoban.homework.media.MediaAssetService;
import com.xiaoban.homework.student.StudentService;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class VoiceMaterialService {
  private final VoiceMaterialBatchRepository batches;
  private final VoiceMaterialPackageRepository packages;
  private final VoiceMaterialFileRepository files;
  private final MediaAssetRepository assets;
  private final MediaAssetService mediaAssets;
  private final StudentService students;
  private final VoiceMediaPolicy mediaPolicy;

  public VoiceMaterialService(VoiceMaterialBatchRepository batches,
      VoiceMaterialPackageRepository packages,
      VoiceMaterialFileRepository files,
      MediaAssetRepository assets,
      MediaAssetService mediaAssets,
      StudentService students,
      VoiceMediaPolicy mediaPolicy) {
    this.batches = batches;
    this.packages = packages;
    this.files = files;
    this.assets = assets;
    this.mediaAssets = mediaAssets;
    this.students = students;
    this.mediaPolicy = mediaPolicy;
  }

  @Transactional
  public VoiceMaterialDtos.BatchResponse createBatch(UUID familyId, String studentId) {
    students.requireOwned(familyId, studentId);
    Instant now = Instant.now();
    VoiceMaterialBatchEntity batch = new VoiceMaterialBatchEntity();
    batch.id = UUID.randomUUID();
    batch.familyId = familyId;
    batch.studentId = studentId;
    batch.directoryCount = 0;
    batch.readyCount = 0;
    batch.invalidCount = 0;
    batch.createdAt = now;
    batch.updatedAt = now;
    return VoiceMaterialDtos.BatchResponse.from(batches.save(batch));
  }

  @Transactional
  public VoiceMaterialDtos.PackageResponse registerPackage(UUID familyId, UUID batchId,
      VoiceMaterialDtos.RegisterPackageRequest input) {
    String studentId = batches.findOwnedStudentId(familyId, batchId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材批次不存在"));
    students.requireOwnedForUpdate(familyId, studentId);
    VoiceMaterialBatchEntity batch = requireBatch(familyId, batchId);
    String subjectCode = input.subjectCode().trim().toUpperCase(Locale.ROOT);
    if (subjectCode.isBlank()) throw new ApiExceptions.BadRequest("请选择科目");
    String directoryName = input.directoryName().trim();
    if (directoryName.isBlank()) throw new ApiExceptions.BadRequest("目录名称不能为空");

    Instant now = Instant.now();
    VoiceMaterialPackageEntity item = new VoiceMaterialPackageEntity();
    item.id = UUID.randomUUID();
    item.batchId = batch.id;
    item.familyId = familyId;
    item.studentId = batch.studentId;
    item.directoryName = directoryName;
    item.subjectCode = subjectCode;
    item.title = input.title() == null || input.title().isBlank()
        ? defaultTitle(directoryName) : input.title().trim();
    item.expectedMinutes = input.expectedMinutes() == null ? 15 : input.expectedMinutes();
    item.dueAt = input.dueAtEpochMs() == null || input.dueAtEpochMs() <= 0
        ? null : Instant.ofEpochMilli(input.dueAtEpochMs());
    item.assignmentType = input.assignmentType() == null || input.assignmentType().isBlank()
        ? "EXTRA" : input.assignmentType().trim().toUpperCase(Locale.ROOT);
    if (!"EXTRA".equals(item.assignmentType) && !"SCHOOL".equals(item.assignmentType)) {
      throw new ApiExceptions.BadRequest("不支持的任务类型");
    }
    item.status = "UPLOADING";
    item.packageFingerprint = null;
    item.consumedAssignmentId = null;
    item.consumedAt = null;
    item.errorMessage = "";
    item.createdAt = now;
    item.updatedAt = now;
    packages.save(item);

    batch.directoryCount++;
    batch.updatedAt = now;
    batches.save(batch);
    return response(item);
  }

  @Transactional
  public VoiceMaterialDtos.FileResponse uploadFile(UUID familyId, UUID packageId,
      String resourceType, String relativeName, int sortOrder, MultipartFile file) {
    String studentId = packages.findOwnedStudentId(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材目录不存在"));
    students.requireOwnedForUpdate(familyId, studentId);
    VoiceMaterialPackageEntity item = packages.lockOwned(familyId, packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材目录不存在"));
    if (!"UPLOADING".equals(item.status)) {
      throw new ApiExceptions.BadRequest("当前目录已结束上传，不能再添加文件");
    }

    String type = resourceType == null ? "" : resourceType.trim().toUpperCase(Locale.ROOT);
    if ("AUDIO".equals(type)) mediaPolicy.validateAudio(file);
    else if ("IMAGE".equals(type)) mediaPolicy.validateImage(file);
    else throw new ApiExceptions.BadRequest("资源类型只支持 AUDIO 或 IMAGE");

    String normalizedName = relativeName == null || relativeName.isBlank()
        ? file.getOriginalFilename() : relativeName.trim();
    if (normalizedName == null || normalizedName.isBlank()) normalizedName = "material";
    if (normalizedName.length() > 300) {
      throw new ApiExceptions.BadRequest("素材文件名不能超过 300 个字符");
    }

    VoiceMaterialFileEntity existing = files
        .findByFamilyIdAndPackageIdAndResourceTypeAndRelativeName(
            familyId, packageId, type, normalizedName)
        .orElse(null);
    if (existing != null) return fileResponse(existing);

    MediaAssetEntity asset = mediaAssets.store(familyId, file);
    VoiceMaterialFileEntity entity = new VoiceMaterialFileEntity();
    entity.id = UUID.randomUUID();
    entity.packageId = packageId;
    entity.familyId = familyId;
    entity.assetId = asset.id;
    entity.resourceType = type;
    entity.relativeName = normalizedName;
    entity.sortOrder = Math.max(0, sortOrder);
    entity.createdAt = Instant.now();
    files.save(entity);
    return fileResponse(entity);
  }

  @Transactional
  public VoiceMaterialDtos.BatchResponse completeBatch(UUID familyId, UUID batchId) {
    String studentId = batches.findOwnedStudentId(familyId, batchId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材批次不存在"));
    students.requireOwnedForUpdate(familyId, studentId);
    VoiceMaterialBatchEntity batch = requireBatch(familyId, batchId);
    List<VoiceMaterialPackageEntity> items =
        packages.findByFamilyIdAndBatchIdOrderByDirectoryNameAscCreatedAtAsc(
            familyId, batch.id);

    int ready = 0;
    int invalid = 0;
    for (VoiceMaterialPackageEntity item : items) {
      if ("CONSUMED".equals(item.status)) {
        ready++;
        continue;
      }
      List<VoiceMaterialFileEntity> packageFiles =
          files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(familyId, item.id);
      long audioCount = packageFiles.stream().filter(file -> "AUDIO".equals(file.resourceType)).count();
      long imageCount = packageFiles.stream().filter(file -> "IMAGE".equals(file.resourceType)).count();
      if (audioCount != 1 || imageCount < 1) {
        item.status = "INVALID";
        item.errorMessage = audioCount == 0 ? "目录缺少语音文件"
            : audioCount > 1 ? "一个目录只能包含一个语音文件" : "目录至少需要一张图片";
        item.updatedAt = Instant.now();
        packages.save(item);
        invalid++;
        continue;
      }

      normalizeSortOrder(packageFiles);
      files.saveAll(packageFiles);
      packageFiles.sort(Comparator.comparingInt(file -> file.sortOrder));

      String fingerprint = fingerprint(item, packageFiles);
      VoiceMaterialPackageEntity duplicate = packages
          .findByFamilyIdAndStudentIdAndPackageFingerprint(familyId, item.studentId, fingerprint)
          .orElse(null);
      if (duplicate != null && !duplicate.id.equals(item.id)) {
        item.status = "INVALID";
        item.errorMessage = "相同目录内容已经导入";
        item.updatedAt = Instant.now();
        packages.save(item);
        invalid++;
        continue;
      }

      item.packageFingerprint = fingerprint;
      item.status = "READY";
      item.errorMessage = "";
      item.updatedAt = Instant.now();
      packages.save(item);
      ready++;
    }
    batch.readyCount = ready;
    batch.invalidCount = invalid;
    batch.updatedAt = Instant.now();
    batches.save(batch);
    return VoiceMaterialDtos.BatchResponse.from(batch);
  }

  @Transactional(readOnly = true)
  public List<VoiceMaterialDtos.PackageResponse> list(UUID familyId, String studentId) {
    students.requireOwned(familyId, studentId);
    return packages.findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(familyId, studentId)
        .stream().map(this::response).toList();
  }

  VoiceMaterialPackageEntity requirePackage(UUID familyId, UUID packageId) {
    VoiceMaterialPackageEntity item = packages.findById(packageId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材目录不存在"));
    if (!familyId.equals(item.familyId)) throw new ApiExceptions.NotFound("语音素材目录不存在");
    return item;
  }

  private VoiceMaterialBatchEntity requireBatch(UUID familyId, UUID batchId) {
    VoiceMaterialBatchEntity batch = batches.findById(batchId)
        .orElseThrow(() -> new ApiExceptions.NotFound("语音素材批次不存在"));
    if (!familyId.equals(batch.familyId)) throw new ApiExceptions.NotFound("语音素材批次不存在");
    return batch;
  }

  private VoiceMaterialDtos.PackageResponse response(VoiceMaterialPackageEntity item) {
    List<VoiceMaterialDtos.FileResponse> fileResponses =
        files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(item.familyId, item.id)
            .stream().map(this::fileResponse).toList();
    return new VoiceMaterialDtos.PackageResponse(
        item.id.toString(), item.batchId.toString(), item.studentId,
        item.directoryName, item.subjectCode, item.title, item.expectedMinutes,
        item.dueAt == null ? 0L : item.dueAt.toEpochMilli(), item.assignmentType,
        item.status, item.errorMessage, item.consumedAssignmentId, fileResponses);
  }

  private VoiceMaterialDtos.FileResponse fileResponse(VoiceMaterialFileEntity file) {
    return new VoiceMaterialDtos.FileResponse(file.id.toString(), file.assetId.toString(),
        file.resourceType, file.relativeName, file.sortOrder);
  }

  private void normalizeSortOrder(List<VoiceMaterialFileEntity> packageFiles) {
    List<VoiceMaterialFileEntity> audio = packageFiles.stream()
        .filter(file -> "AUDIO".equals(file.resourceType))
        .toList();
    if (!audio.isEmpty()) audio.get(0).sortOrder = 0;

    List<VoiceMaterialFileEntity> images = packageFiles.stream()
        .filter(file -> "IMAGE".equals(file.resourceType))
        .sorted(Comparator.comparing(
            file -> file.relativeName.toLowerCase(Locale.ROOT)))
        .toList();
    for (int i = 0; i < images.size(); i++) images.get(i).sortOrder = i + 1;
  }

  private String fingerprint(VoiceMaterialPackageEntity item,
      List<VoiceMaterialFileEntity> packageFiles) {
    StringBuilder canonical = new StringBuilder();
    canonical.append(item.studentId).append('\n')
        .append(item.directoryName).append('\n');
    for (VoiceMaterialFileEntity file : packageFiles) {
      MediaAssetEntity asset = assets.findById(file.assetId)
          .orElseThrow(() -> new ApiExceptions.NotFound("媒体资源不存在"));
      canonical.append(file.resourceType).append('|')
          .append(file.relativeName).append('|')
          .append(asset.sha256).append('|')
          .append(asset.sizeBytes).append('\n');
    }
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(
          digest.digest(canonical.toString().getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException error) {
      throw new IllegalStateException("无法计算素材目录摘要", error);
    }
  }

  private String defaultTitle(String directoryName) {
    return directoryName.replaceFirst("^\\d+[\\s._-]*", "").trim().isBlank()
        ? directoryName
        : directoryName.replaceFirst("^\\d+[\\s._-]*", "").trim();
  }
}
