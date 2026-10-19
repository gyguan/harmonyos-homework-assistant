package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeworkOrganizerFeedbackService {
  private final StudentRepository students;
  private final HomeworkFeedbackTypeRepository types;
  private final HomeworkOrganizerFeedbackRepository feedback;
  private final HomeworkTeacherExperienceRepository experiences;

  public HomeworkOrganizerFeedbackService(StudentRepository students,
      HomeworkFeedbackTypeRepository types, HomeworkOrganizerFeedbackRepository feedback) {
    this(students, types, feedback, null);
  }

  @Autowired
  public HomeworkOrganizerFeedbackService(StudentRepository students,
      HomeworkFeedbackTypeRepository types, HomeworkOrganizerFeedbackRepository feedback,
      HomeworkTeacherExperienceRepository experiences) {
    this.students = students;
    this.types = types;
    this.feedback = feedback;
    this.experiences = experiences;
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
    entity.teacherName = HomeworkTeacherAttribution.resolve(
        request.teacherName(), request.subject(), request.sourceLabel(), request.sourceExcerpt());
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

  /**
   * Parent expressly promotes one verified shorthand correction. A feedback
   * submission by itself never trains the model or modifies shared rules.
   */
  @Transactional
  public HomeworkTeacherExperienceDtos.Response promote(UUID familyId, String studentId,
      UUID feedbackId, HomeworkOrganizerFeedbackDtos.Promote request) {
    requireOwned(familyId, studentId);
    if (experiences == null) throw new ApiExceptions.ServiceUnavailable("老师经验库不可用");
    HomeworkOrganizerFeedbackEntity record = feedback
        .findByIdAndFamilyIdAndStudentId(feedbackId, familyId, studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("反馈不存在"));
    HomeworkFeedbackTypeEntity type = types.findById(record.feedbackTypeCode)
        .filter(t -> t.enabled && t.canBecomeExperience)
        .orElseThrow(() -> new ApiExceptions.BadRequest("该反馈类型暂不支持直接转成经验"));
    // No teacher directory prerequisite: the persisted feedback already has student ownership.
    // Unidentified teacher remains a subject-scoped rule rather than an invented identity.
    String teacher = HomeworkTeacherAttribution.resolve(
        record.teacherName, record.subject, record.sourceLabel, record.sourceExcerpt);
    String cue = request.cue().trim();
    String interpretation = request.interpretation().trim();
    if (!HomeworkExperienceCueMatcher.valid(cue)
        || !HomeworkExperienceCueMatcher.matches(cue, record.sourceExcerpt)
        || cue.equals("作业") || cue.equals("老师")) {
      throw new ApiExceptions.BadRequest("触发词必须在老师原文中出现；* 可代替1至3位数字");
    }
    if (interpretation.length() < 6) {
      throw new ApiExceptions.BadRequest("请填写准确的缩写含义或完成要求");
    }
    var prior = experiences.findBySourceFeedbackId(record.id);
    if (prior.isPresent()) {
      var existing = prior.get();
      // The same confirmed feedback cannot silently rewrite its earlier
      // interpretation. A disabled rule can be explicitly enabled again.
      if (!existing.cue.equals(cue) || !existing.interpretation.equals(interpretation)) {
        throw new ApiExceptions.Conflict("该反馈已有经验，修改前请先删除旧规则并重新反馈");
      }
      existing.active = true;
      existing.updatedAt = Instant.now();
      record.processingStatus = "APPLIED";
      feedback.save(record);
      return HomeworkTeacherExperienceDtos.Response.from(experiences.save(existing));
    }
    if (!"NEW".equals(record.processingStatus)) {
      throw new ApiExceptions.Conflict("反馈状态不允许生成规则");
    }
    long count = experiences.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId).size();
    if (count >= 80) throw new ApiExceptions.BadRequest("该学生的老师经验已达上限");
    var entity = new HomeworkTeacherExperienceEntity();
    entity.id = UUID.randomUUID();
    entity.familyId = familyId;
    entity.studentId = studentId;
    entity.teacherName = teacher;
    entity.subject = record.subject;
    entity.cue = cue;
    entity.interpretation = interpretation;
    entity.exampleSource = record.sourceExcerpt.length() <= 400
        ? record.sourceExcerpt : record.sourceExcerpt.substring(0, 400);
    entity.exampleResult = record.currentTitle.equals(record.originalTitle)
        ? "" : record.currentTitle;
    entity.origin = "FEEDBACK_APPROVED";
    entity.active = true;
    entity.sourceFeedbackId = record.id;
    entity.createdAt = Instant.now();
    entity.updatedAt = entity.createdAt;
    var saved = experiences.save(entity);
    record.processingStatus = "APPLIED";
    feedback.save(record);
    return HomeworkTeacherExperienceDtos.Response.from(saved);
  }

  private static String clean(String s) {
    return s == null ? "" : s.trim();
  }
}
