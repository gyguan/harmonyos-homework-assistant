package com.xiaoban.homework.submission;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentRepository;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.assignment.VoiceMediaPolicy;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.storage.FileStorage;
import com.xiaoban.homework.storage.FileTransactionCoordinator;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class SubmissionService {
  private static final Logger log = LoggerFactory.getLogger(SubmissionService.class);
  private static final long MIN_AUDIO_DURATION_MS = 3_000;
  private static final long MAX_AUDIO_DURATION_MS = 10 * 60_000;

  private final SubmissionRepository submissions;
  private final SubmissionResourceRepository resources;
  private final AssignmentService assignments;
  private final AssignmentRepository assignmentRepository;
  private final FileStorage storage;
  private final FileTransactionCoordinator fileTransactions;
  private final VoiceMediaPolicy mediaPolicy;

  public SubmissionService(
      SubmissionRepository submissions,
      SubmissionResourceRepository resources,
      AssignmentService assignments,
      AssignmentRepository assignmentRepository,
      FileStorage storage,
      FileTransactionCoordinator fileTransactions,
      VoiceMediaPolicy mediaPolicy) {
    this.submissions = submissions;
    this.resources = resources;
    this.assignments = assignments;
    this.assignmentRepository = assignmentRepository;
    this.storage = storage;
    this.fileTransactions = fileTransactions;
    this.mediaPolicy = mediaPolicy;
  }

  @Transactional
  public SubmissionDtos.CreateResponse create(
      UUID familyId,
      String assignmentId,
      long expectedVersion,
      List<MultipartFile> photoFiles,
      MultipartFile audio,
      long audioDurationMs) {
    AssignmentEntity assignment = assignments.requireOwned(familyId, assignmentId);
    if (assignment.version != expectedVersion) {
      throw new ApiExceptions.Conflict("作业已在其他设备更新，请刷新后重试");
    }
    if (!"READY_TO_SUBMIT".equals(assignment.status)) {
      throw new ApiExceptions.BadRequest("只有待提交作业才能提交");
    }

    List<MultipartFile> safePhotos = photoFiles == null ? Collections.emptyList() : photoFiles;
    boolean voiceAssignment = "AUDIO_IMAGE".equals(assignment.contentType);
    if (voiceAssignment) {
      if (!safePhotos.isEmpty()) {
        throw new ApiExceptions.BadRequest("语音作业请提交学生录音，不需要提交照片");
      }
      mediaPolicy.validateAudio(audio);
      if (audioDurationMs < MIN_AUDIO_DURATION_MS || audioDurationMs > MAX_AUDIO_DURATION_MS) {
        throw new ApiExceptions.BadRequest("录音时长需为 3 秒到 10 分钟");
      }
    } else {
      if (audio != null && !audio.isEmpty()) {
        throw new ApiExceptions.BadRequest("普通作业请提交照片");
      }
      if (safePhotos.isEmpty() || safePhotos.size() > 6) {
        throw new ApiExceptions.BadRequest("作业照片数量必须为 1-6 张");
      }
      for (MultipartFile file : safePhotos) mediaPolicy.validateImage(file);
    }

    Instant now = Instant.now();
    UUID submissionId = UUID.randomUUID();
    SubmissionEntity submission = new SubmissionEntity();
    submission.id = submissionId;
    submission.familyId = familyId;
    submission.assignmentId = assignmentId;
    submission.submittedAt = now;
    submission.createdAt = now;
    submissions.save(submission);

    List<SubmissionDtos.Resource> result = new ArrayList<>();
    long totalBytes = 0;
    if (voiceAssignment) {
      SubmissionResourceEntity stored =
          saveResource(submissionId, familyId, assignmentId, audio, "AUDIO", audioDurationMs, 0, now);
      totalBytes += stored.sizeBytes;
      result.add(toDto(stored));
    } else {
      for (int i = 0; i < safePhotos.size(); i++) {
        SubmissionResourceEntity stored =
            saveResource(submissionId, familyId, assignmentId, safePhotos.get(i), "IMAGE", 0, i, now);
        totalBytes += stored.sizeBytes;
        result.add(toDto(stored));
      }
    }

    assignment.status = "SUBMITTED";
    assignment.startedAtEpochMs = 0;
    assignment.updatedAt = now;
    AssignmentDtos.Response authoritative =
        AssignmentDtos.Response.from(assignmentRepository.saveAndFlush(assignment));

    SubmissionDtos.Response created =
        new SubmissionDtos.Response(submissionId, assignmentId, now, result, legacyPhotos(result));
    log.info(
        "submission created assignmentId={} studentId={} submissionId={} resourceType={} resourceCount={} totalBytes={} from=READY_TO_SUBMIT to=SUBMITTED",
        assignmentId,
        assignment.studentId,
        submissionId,
        voiceAssignment ? "AUDIO" : "IMAGE",
        result.size(),
        totalBytes);
    return new SubmissionDtos.CreateResponse(created, authoritative);
  }

  @Transactional(readOnly = true)
  public List<SubmissionDtos.Response> list(UUID familyId, String assignmentId) {
    assignments.requireOwned(familyId, assignmentId);
    return submissions.findByFamilyIdAndAssignmentIdOrderBySubmittedAtDesc(familyId, assignmentId)
        .stream().map(this::toDto).toList();
  }

  @Transactional(readOnly = true)
  public SubmissionDtos.Response latest(UUID familyId, String assignmentId) {
    assignments.requireOwned(familyId, assignmentId);
    return submissions.findFirstByFamilyIdAndAssignmentIdOrderBySubmittedAtDesc(familyId, assignmentId)
        .map(this::toDto).orElse(null);
  }

  @Transactional(readOnly = true)
  public ResourceDownload resource(UUID familyId, UUID resourceId, String requiredType) {
    SubmissionResourceEntity resource = resources.findById(resourceId)
        .orElseThrow(() -> new ApiExceptions.NotFound("提交资源不存在"));
    if (!familyId.equals(resource.familyId)) {
      throw new ApiExceptions.NotFound("提交资源不存在");
    }
    if (requiredType != null && !requiredType.equals(resource.resourceType)) {
      throw new ApiExceptions.NotFound("提交资源不存在");
    }
    return new ResourceDownload(
        storage.resolve(resource.storagePath), resource.originalName, resource.contentType);
  }

  private SubmissionResourceEntity saveResource(
      UUID submissionId,
      UUID familyId,
      String assignmentId,
      MultipartFile file,
      String type,
      long durationMs,
      int sortOrder,
      Instant now) {
    UUID resourceId = UUID.randomUUID();
    FileStorage.StoredFile stored = storage.save(resourceId, file);
    fileTransactions.deleteOnRollback(stored.storagePath());

    SubmissionResourceEntity resource = new SubmissionResourceEntity();
    resource.id = resourceId;
    resource.submissionId = submissionId;
    resource.familyId = familyId;
    resource.assignmentId = assignmentId;
    resource.resourceType = type;
    resource.storagePath = stored.storagePath();
    resource.originalName = stored.originalName();
    resource.contentType = stored.contentType();
    resource.sizeBytes = stored.sizeBytes();
    resource.durationMs = durationMs;
    resource.sortOrder = sortOrder;
    resource.createdAt = now;
    return resources.save(resource);
  }

  private SubmissionDtos.Response toDto(SubmissionEntity submission) {
    List<SubmissionDtos.Resource> list = resources
        .findBySubmissionIdOrderBySortOrderAscIdAsc(submission.id)
        .stream().map(this::toDto).toList();
    return new SubmissionDtos.Response(
        submission.id, submission.assignmentId, submission.submittedAt, list, legacyPhotos(list));
  }

  private List<SubmissionDtos.Resource> legacyPhotos(List<SubmissionDtos.Resource> resources) {
    List<SubmissionDtos.Resource> result = new ArrayList<>();
    for (SubmissionDtos.Resource resource : resources) {
      if (!"IMAGE".equals(resource.resourceType())) continue;
      result.add(new SubmissionDtos.Resource(
          resource.id(),
          resource.resourceType(),
          resource.originalName(),
          resource.contentType(),
          resource.sizeBytes(),
          resource.durationMs(),
          resource.sortOrder(),
          "/api/v1/submission-photos/" + resource.id()));
    }
    return result;
  }

  private SubmissionDtos.Resource toDto(SubmissionResourceEntity resource) {
    return new SubmissionDtos.Resource(
        resource.id,
        resource.resourceType,
        resource.originalName,
        resource.contentType,
        resource.sizeBytes,
        resource.durationMs,
        resource.sortOrder,
        "/api/v1/submission-resources/" + resource.id);
  }

  public record ResourceDownload(Path path, String originalName, String contentType) {}
}
