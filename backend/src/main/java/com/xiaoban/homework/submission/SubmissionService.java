package com.xiaoban.homework.submission;

import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.assignment.AssignmentStatePolicy;
import com.xiaoban.homework.common.ApiExceptions;
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
public class SubmissionService {
  private final SubmissionRepository submissions; private final SubmissionPhotoRepository photos;
  private final AssignmentService assignments; private final FileStorage storage;
  public SubmissionService(SubmissionRepository submissions, SubmissionPhotoRepository photos, AssignmentService assignments, FileStorage storage) {
    this.submissions = submissions; this.photos = photos; this.assignments = assignments; this.storage = storage;
  }

  @Transactional
  public SubmissionDtos.Response create(UUID familyId, String assignmentId, List<MultipartFile> files) {
    if (files == null || files.isEmpty() || files.size() > 6) throw new ApiExceptions.BadRequest("作业照片数量必须为 1-6 张");
    AssignmentEntity assignment = assignments.requireOwned(familyId, assignmentId);
    if (!AssignmentStatePolicy.canTransition(assignment.status, "SUBMITTED")) throw new ApiExceptions.BadRequest("当前作业状态不能提交");
    Instant now = Instant.now(); UUID submissionId = UUID.randomUUID();
    SubmissionEntity submission = new SubmissionEntity(); submission.id = submissionId; submission.familyId = familyId;
    submission.assignmentId = assignmentId; submission.submittedAt = now; submission.createdAt = now; submissions.save(submission);
    List<SubmissionDtos.Photo> result = new ArrayList<>();
    for (MultipartFile file : files) {
      UUID photoId = UUID.randomUUID(); FileStorage.StoredFile stored = storage.save(photoId, file);
      SubmissionPhotoEntity photo = new SubmissionPhotoEntity(); photo.id = photoId; photo.submissionId = submissionId;
      photo.familyId = familyId; photo.assignmentId = assignmentId; photo.storagePath = stored.storagePath();
      photo.originalName = stored.originalName(); photo.contentType = stored.contentType(); photo.sizeBytes = stored.sizeBytes(); photos.save(photo);
      result.add(toDto(photo));
    }
    assignment.status = "SUBMITTED"; assignment.updatedAt = now;
    return new SubmissionDtos.Response(submissionId, assignmentId, now, result);
  }

  @Transactional(readOnly = true)
  public List<SubmissionDtos.Response> list(UUID familyId, String assignmentId) {
    assignments.requireOwned(familyId, assignmentId);
    return submissions.findByFamilyIdAndAssignmentIdOrderBySubmittedAtDesc(familyId, assignmentId).stream().map(this::toDto).toList();
  }

  @Transactional(readOnly = true)
  public PhotoDownload photo(UUID familyId, UUID photoId) {
    SubmissionPhotoEntity photo = photos.findById(photoId).orElseThrow(() -> new ApiExceptions.NotFound("照片不存在"));
    if (!familyId.equals(photo.familyId)) throw new ApiExceptions.NotFound("照片不存在");
    return new PhotoDownload(storage.resolve(photo.storagePath), photo.originalName, photo.contentType);
  }

  private SubmissionDtos.Response toDto(SubmissionEntity s) {
    List<SubmissionDtos.Photo> list = photos.findBySubmissionIdOrderById(s.id).stream().map(this::toDto).toList();
    return new SubmissionDtos.Response(s.id, s.assignmentId, s.submittedAt, list);
  }
  private SubmissionDtos.Photo toDto(SubmissionPhotoEntity p) {
    return new SubmissionDtos.Photo(p.id, p.originalName, p.contentType, p.sizeBytes, "/api/v1/submission-photos/" + p.id);
  }
  public record PhotoDownload(Path path, String originalName, String contentType) {}
}
