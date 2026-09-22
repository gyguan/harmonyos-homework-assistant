package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.media.MediaAssetEntity;
import com.xiaoban.homework.media.MediaAssetService;
import com.xiaoban.homework.storage.FileStorage;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class AssignmentResourceService {
  private final AssignmentService assignments;
  private final AssignmentResourceRepository resources;
  private final FileStorage storage;
  private final MediaAssetService mediaAssets;
  private final VoiceMediaPolicy mediaPolicy;

  public AssignmentResourceService(AssignmentService assignments,
      AssignmentResourceRepository resources, FileStorage storage,
      MediaAssetService mediaAssets, VoiceMediaPolicy mediaPolicy) {
    this.assignments = assignments;
    this.resources = resources;
    this.storage = storage;
    this.mediaAssets = mediaAssets;
    this.mediaPolicy = mediaPolicy;
  }

  @Transactional
  public AssignmentResourceDtos.VoiceCreateResponse createVoiceAssignment(UUID familyId,
      String studentId, AssignmentDtos.Create input, MultipartFile audio, List<MultipartFile> images) {
    mediaPolicy.validateAudio(audio);
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

  @Transactional
  public List<AssignmentResourceDtos.Response> linkAssets(UUID familyId, String assignmentId,
      List<AssetLink> links) {
    assignments.requireOwned(familyId, assignmentId);
    List<AssignmentResourceEntity> existing =
        resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(familyId, assignmentId);
    if (!existing.isEmpty()) {
      return existing.stream().map(AssignmentResourceDtos.Response::from).toList();
    }

    List<AssignmentResourceEntity> created = new ArrayList<>();
    for (AssetLink link : links) {
      MediaAssetEntity asset = mediaAssets.requireOwned(familyId, link.assetId());
      AssignmentResourceEntity entity = new AssignmentResourceEntity();
      entity.id = UUID.randomUUID();
      entity.familyId = familyId;
      entity.assignmentId = assignmentId;
      entity.resourceType = link.resourceType();
      entity.storagePath = null;
      entity.assetId = asset.id;
      entity.originalName = link.originalName() == null || link.originalName().isBlank()
          ? asset.originalName : link.originalName();
      entity.contentType = link.contentType() == null || link.contentType().isBlank()
          ? asset.contentType : link.contentType();
      entity.sizeBytes = asset.sizeBytes;
      entity.sortOrder = link.sortOrder();
      entity.durationMs = link.durationMs();
      entity.createdAt = Instant.now();
      created.add(entity);
    }
    resources.saveAll(created);
    resources.flush();
    return created.stream().map(AssignmentResourceDtos.Response::from).toList();
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

  void validateImages(List<MultipartFile> images) {
    if (images == null || images.isEmpty()) {
      throw new ApiExceptions.BadRequest("请至少选择 1 张情景图片");
    }
    for (MultipartFile image : images) {
      mediaPolicy.validateImage(image);
    }
  }

  public record AssetLink(String resourceType, UUID assetId, int sortOrder, long durationMs,
      String originalName, String contentType) {}
  public record ResourceDownload(Path path, String originalName, String contentType) {}
}
