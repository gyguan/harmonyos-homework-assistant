package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.media.MediaAssetService;
import com.xiaoban.homework.storage.FileStorage;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class AssignmentResourceService {
  private static final long MAX_AUDIO_BYTES = 20L * 1024 * 1024;
  private static final long MAX_IMAGE_BYTES = 5L * 1024 * 1024;

  private final AssignmentService assignments;
  private final AssignmentResourceRepository resources;
  private final FileStorage storage;
  private final MediaAssetService mediaAssets;

  public AssignmentResourceService(AssignmentService assignments,
      AssignmentResourceRepository resources, FileStorage storage,
      MediaAssetService mediaAssets) {
    this.assignments = assignments;
    this.resources = resources;
    this.storage = storage;
    this.mediaAssets = mediaAssets;
  }

  @Transactional
  public AssignmentResourceDtos.VoiceCreateResponse createVoiceAssignment(UUID familyId,
      String studentId, AssignmentDtos.Create input, MultipartFile audio, List<MultipartFile> images) {
    validateAudio(audio);
    validateImages(images);

    AssignmentDtos.Create voiceInput = new AssignmentDtos.Create(
        input.id(), input.subject(), input.title(), input.instruction(), input.textbookRef(),
        input.dueText(), input.assignmentType(), input.subjectCode(), "AUDIO_IMAGE",
        input.dueAtEpochMs(), input.dueTimezone(), input.status(), input.sourceLabel(),
        input.sourceExcerpt(), input.expectedMinutes(), input.startedAtEpochMs(),
        input.finishedAtEpochMs(), input.elapsedSeconds(), input.reviewNote());

    List<String> savedPaths = new ArrayList<>();
    try {
      AssignmentDtos.Response assignment = assignments.create(familyId, studentId, voiceInput);
      List<AssignmentResourceEntity> existing =
          resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(familyId, assignment.id());
      if (!existing.isEmpty()) {
        return new AssignmentResourceDtos.VoiceCreateResponse(
            assignment, existing.stream().map(AssignmentResourceDtos.Response::from).toList());
      }

      List<AssignmentResourceEntity> created = new ArrayList<>();
      created.add(saveResource(familyId, assignment.id(), "AUDIO", audio, 0, savedPaths));
      for (int i = 0; i < images.size(); i++) {
        created.add(saveResource(familyId, assignment.id(), "IMAGE", images.get(i), i + 1, savedPaths));
      }
      resources.saveAll(created);
      resources.flush();
      return new AssignmentResourceDtos.VoiceCreateResponse(
          assignment, created.stream().map(AssignmentResourceDtos.Response::from).toList());
    } catch (RuntimeException error) {
      for (String path : savedPaths) {
        try {
          storage.delete(path);
        } catch (RuntimeException ignored) {
          // Preserve the primary publish error. Orphan cleanup can be retried operationally.
        }
      }
      throw error;
    }
  }

  @Transactional(readOnly = true)
  public List<AssignmentResourceDtos.Response> list(UUID familyId, String assignmentId) {
    assignments.requireOwned(familyId, assignmentId);
    return resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(familyId, assignmentId)
        .stream().map(AssignmentResourceDtos.Response::from).toList();
  }

  @Transactional(readOnly = true)
  public ResourceDownload download(UUID familyId, UUID resourceId) {
    AssignmentResourceEntity resource = resources.findById(resourceId)
        .orElseThrow(() -> new ApiExceptions.NotFound("作业资料不存在"));
    if (!familyId.equals(resource.familyId)) throw new ApiExceptions.NotFound("作业资料不存在");
    assignments.requireOwned(familyId, resource.assignmentId);
    Path path;
    if (resource.assetId != null) {
      path = mediaAssets.resolveOwned(familyId, resource.assetId).path();
    } else {
      path = storage.resolve(resource.storagePath);
    }
    return new ResourceDownload(path, resource.originalName, resource.contentType);
  }

  private AssignmentResourceEntity saveResource(UUID familyId, String assignmentId,
      String resourceType, MultipartFile file, int sortOrder, List<String> savedPaths) {
    UUID id = UUID.randomUUID();
    FileStorage.StoredFile stored = storage.save(id, file);
    savedPaths.add(stored.storagePath());

    AssignmentResourceEntity entity = new AssignmentResourceEntity();
    entity.id = id;
    entity.familyId = familyId;
    entity.assignmentId = assignmentId;
    entity.resourceType = resourceType;
    entity.storagePath = stored.storagePath();
    entity.originalName = stored.originalName();
    entity.contentType = stored.contentType();
    entity.sizeBytes = stored.sizeBytes();
    entity.sortOrder = sortOrder;
    entity.durationMs = 0;
    entity.createdAt = Instant.now();
    return entity;
  }

  private void validateAudio(MultipartFile audio) {
    if (audio == null || audio.isEmpty()) throw new ApiExceptions.BadRequest("请选择一个语音文件");
    if (audio.getSize() > MAX_AUDIO_BYTES) throw new ApiExceptions.BadRequest("语音文件不能超过 20MB");
    String type = mediaType(audio);
    String name = fileName(audio);
    boolean supported = type.equals("audio/mpeg") || type.equals("audio/mp4") ||
        type.equals("audio/x-m4a") || type.equals("audio/wav") || type.equals("audio/x-wav") ||
        name.endsWith(".mp3") || name.endsWith(".m4a") || name.endsWith(".wav");
    if (!supported) throw new ApiExceptions.BadRequest("仅支持 mp3、m4a、wav 语音文件");
  }

  void validateImages(List<MultipartFile> images) {
    if (images == null || images.isEmpty()) {
      throw new ApiExceptions.BadRequest("请至少选择 1 张情景图片");
    }
    for (MultipartFile image : images) {
      if (image == null || image.isEmpty()) throw new ApiExceptions.BadRequest("图片文件不能为空");
      if (image.getSize() > MAX_IMAGE_BYTES) throw new ApiExceptions.BadRequest("单张图片不能超过 5MB");
      String type = mediaType(image);
      String name = fileName(image);
      boolean supported = type.equals("image/jpeg") || type.equals("image/png") ||
          type.equals("image/webp") || type.equals("image/heic") ||
          name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".png") ||
          name.endsWith(".webp") || name.endsWith(".heic");
      if (!supported) throw new ApiExceptions.BadRequest("仅支持 jpg、png、webp、heic 图片");
    }
  }

  private String mediaType(MultipartFile file) {
    String value = file.getContentType();
    return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
  }

  private String fileName(MultipartFile file) {
    String value = file.getOriginalFilename();
    return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
  }

  public record ResourceDownload(Path path, String originalName, String contentType) {}
}
