package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeworkOrganizerFeedbackService {
  private final StudentRepository students;
  private final HomeworkFeedbackTypeRepository types;
  private final HomeworkOrganizerFeedbackRepository feedback;

  public HomeworkOrganizerFeedbackService(StudentRepository students,
      HomeworkFeedbackTypeRepository types, HomeworkOrganizerFeedbackRepository feedback) {
    this.students = students;
    this.types = types;
    this.feedback = feedback;
  }

  private void requireOwned(UUID familyId, String studentId) {
    var student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
  }

  @Transactional(readOnly = true)
  public List<HomeworkOrganizerFeedbackDtos.TypeResponse> types(UUID familyId, String studentId) {
    requireOwned(familyId, studentId);
    return types.findByEnabledTrueOrderByDisplayOrderAsc().stream()
        .map(HomeworkOrganizerFeedbackDtos.TypeResponse::from).toList();
  }

  @Transactional(readOnly = true)
  public List<HomeworkOrganizerFeedbackDtos.Response> history(UUID familyId, String studentId) {
    requireOwned(familyId, studentId);
    return feedback.findTop50ByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, studentId)
        .stream().map(HomeworkOrganizerFeedbackDtos.Response::from).toList();
  }

  @Transactional
  public HomeworkOrganizerFeedbackDtos.Response submit(UUID familyId, String studentId,
      HomeworkOrganizerFeedbackDtos.Create request) {
    requireOwned(familyId, studentId);
    String clientRequestId = request.clientRequestId().trim();
    var existing = feedback.findByFamilyIdAndStudentIdAndClientRequestId(
        familyId, studentId, clientRequestId);
    if (existing.isPresent()) return HomeworkOrganizerFeedbackDtos.Response.from(existing.get());
    var type = types.findById(request.feedbackTypeCode().trim())
        .filter(t -> t.enabled)
        .orElseThrow(() -> new ApiExceptions.BadRequest("反馈类型不存在或已停用"));
    String details = clean(request.details());
    if (type.requiresComment && details.isEmpty()) {
      throw new ApiExceptions.BadRequest("该反馈类型需要填写具体问题");
    }

    var entity = new HomeworkOrganizerFeedbackEntity();
    entity.id = UUID.randomUUID();
    entity.familyId = familyId;
    entity.studentId = studentId;
    entity.clientRequestId = clientRequestId;
    entity.candidateId = request.candidateId().trim();
    entity.batchId = clean(request.batchId());
    entity.teacherName = clean(request.teacherName());
    entity.subject = request.subject().trim();
    entity.feedbackTypeCode = type.code;
    entity.sourceLabel = clean(request.sourceLabel());
    entity.sourceExcerpt = clean(request.sourceExcerpt());
    entity.originalTitle = clean(request.originalTitle());
    entity.currentTitle = clean(request.currentTitle());
    entity.details = details;
    // 原始反馈只作为证据，不能未经验证就写入 AI 的通用或老师经验。
    entity.processingStatus = "NEW";
    entity.createdAt = Instant.now();
    return HomeworkOrganizerFeedbackDtos.Response.from(feedback.save(entity));
  }

  private static String clean(String s) {
    return s == null ? "" : s.trim();
  }
}
