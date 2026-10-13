package com.xiaoban.homework.organizer;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
public class HomeworkOrganizerService {
  private static final Logger log = LoggerFactory.getLogger(HomeworkOrganizerService.class);
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");
  private final StudentRepository students;
  private final AssignmentService assignments;
  private final HomeworkOrganizerModelClient model;

  public HomeworkOrganizerService(StudentRepository students, AssignmentService assignments,
      HomeworkOrganizerModelClient model) {
    this.students = students;
    this.assignments = assignments;
    this.model = model;
  }

  public HomeworkOrganizerDtos.Response organize(UUID familyId, String studentId, HomeworkOrganizerDtos.Request request) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    if (!model.available()) throw new ApiExceptions.ServiceUnavailable("AI整理暂未配置");

    List<HomeworkOrganizerDtos.Candidate> organized = model
        .organize(student, request.sourceLabel(), request.text())
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI整理暂时不可用"));
    List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments =
        needsTodayDuplicateReview(organized) ? existingAssignments(familyId, studentId) : List.of();
    List<HomeworkOrganizerDtos.Candidate> reviewed =
        reviewDuplicates(organized, existingAssignments, request.text());
    log.info("homework_import organized studentId={} assignments={} existingContext={} duplicateHints={}",
        studentId, reviewed.size(), existingAssignments.size(),
        reviewed.stream().filter(item -> item.duplicateAssignmentId() != null &&
            !item.duplicateAssignmentId().isBlank()).count());
    return new HomeworkOrganizerDtos.Response(reviewed, "AI");
  }

  public HomeworkOrganizerDtos.ImageResponse organizeImage(UUID familyId, String studentId,
      HomeworkOrganizerDtos.ImageRequest request) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    String imageDataUrl = HomeworkImageInput.dataUrl(request);
    if (!model.imageAvailable()) throw new ApiExceptions.ServiceUnavailable("AI图片解析暂未配置，请使用识别图片文字");
    var result = model.organizeImage(
        student, request.sourceLabel(), imageDataUrl, request.text())
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI图片解析失败，请确认模型支持图片，或点击识别图片文字"));
    List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments =
        needsTodayDuplicateReview(result.assignments()) ? existingAssignments(familyId, studentId) : List.of();
    List<HomeworkOrganizerDtos.Candidate> reviewed =
        reviewDuplicates(result.assignments(), existingAssignments, result.recognizedText());
    var reviewedResult = new HomeworkOrganizerDtos.ImageResponse(
        reviewed, result.mode(), result.recognizedText());
    log.info("homework_import image_parsed studentId={} assignments={} existingContext={} duplicateHints={}",
        studentId, reviewed.size(), existingAssignments.size(),
        reviewed.stream().filter(item -> item.duplicateAssignmentId() != null &&
            !item.duplicateAssignmentId().isBlank()).count());
    return reviewedResult;
  }

  private List<HomeworkOrganizerDtos.Candidate> reviewDuplicates(
      List<HomeworkOrganizerDtos.Candidate> candidates,
      List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments,
      String sourceText) {
    if (existingAssignments == null || existingAssignments.isEmpty()) return candidates;
    return model.reviewDuplicates(candidates, existingAssignments, sourceText)
        .orElseGet(() -> {
          log.warn("homework_import duplicate_ai_fallback candidates={} existingContext={}",
              candidates == null ? 0 : candidates.size(), existingAssignments.size());
          return markLocalFallback(ConfigurableHomeworkOrganizerModelClient.reviewLocalDuplicates(
              candidates, existingAssignments, sourceText));
        });
  }

  private List<HomeworkOrganizerDtos.Candidate> markLocalFallback(
      List<HomeworkOrganizerDtos.Candidate> candidates) {
    if (candidates == null || candidates.isEmpty()) return candidates == null ? List.of() : candidates;
    List<HomeworkOrganizerDtos.Candidate> result = new ArrayList<>();
    for (HomeworkOrganizerDtos.Candidate candidate : candidates) {
      if (candidate == null) continue;
      String reason = candidate.duplicateReason();
      if (candidate.duplicateAssignmentId() != null && !candidate.duplicateAssignmentId().isBlank()) {
        String detail = reason == null || reason.isBlank() ? "本地规则识别为疑似重复" : reason.trim();
        reason = "【本地兜底】" + detail;
      }
      result.add(new HomeworkOrganizerDtos.Candidate(
          candidate.subject(), candidate.title(), candidate.instruction(), candidate.textbookRef(),
          candidate.taskDate(), candidate.expectedMinutes(), candidate.sourceExcerpt(), candidate.confidence(),
          candidate.sameTaskGroup(), candidate.duplicateAssignmentId(), candidate.duplicateAssignmentTitle(),
          candidate.duplicateConfidence(), reason));
    }
    return result;
  }

  private boolean needsTodayDuplicateReview(List<HomeworkOrganizerDtos.Candidate> candidates) {
    if (candidates == null || candidates.isEmpty()) return false;
    LocalDate today = LocalDate.now(BUSINESS_ZONE);
    for (HomeworkOrganizerDtos.Candidate candidate : candidates) {
      if (candidate == null) continue;
      LocalDate dueDate = ConfigurableHomeworkOrganizerModelClient.candidateTaskDate(candidate.taskDate());
      if (today.equals(dueDate)) return true;
    }
    return false;
  }

  private List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments(
      UUID familyId, String studentId) {
    LocalDate today = LocalDate.now(BUSINESS_ZONE);
    long from = today.atStartOfDay(BUSINESS_ZONE).toInstant().toEpochMilli();
    long toInclusive = today.plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant().toEpochMilli() - 1L;
    String activeStatuses =
        "NOT_STARTED,IN_PROGRESS,PAUSED,READY_TO_SUBMIT,NEEDS_REWORK,OVERDUE";

    List<HomeworkOrganizerDtos.ExistingAssignment> result = new ArrayList<>();
    List<AssignmentDtos.Response> todayItems = assignments.list(
        familyId, studentId, null, null, from, toInclusive, activeStatuses);
    appendExisting(result, todayItems);

    long evidenceCount =
        result.stream().filter(item -> item.sourceExcerpt() != null && !item.sourceExcerpt().isBlank()).count();
    log.info("homework_import duplicate_context studentId={} scope=TODAY selected={} evidence={}",
        studentId, result.size(), evidenceCount);
    return result;
  }

  private void appendExisting(List<HomeworkOrganizerDtos.ExistingAssignment> result,
      List<AssignmentDtos.Response> items) {
    for (AssignmentDtos.Response item : items) {
      if (result.size() >= 30) break;
      result.add(new HomeworkOrganizerDtos.ExistingAssignment(
          item.id(), item.subject(), item.title(), item.instruction(), item.textbookRef(),
          item.taskDate(), item.sourceExcerpt()));
    }
  }
}
