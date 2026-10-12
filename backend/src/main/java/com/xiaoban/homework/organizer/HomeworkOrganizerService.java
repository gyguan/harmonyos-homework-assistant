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

    List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments =
        existingAssignments(familyId, studentId);
    List<HomeworkOrganizerDtos.Candidate> organized = model
        .organize(student, request.sourceLabel(), request.text(), existingAssignments)
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI整理暂时不可用"));
    log.info("homework_import organized studentId={} assignments={} existingContext={} duplicateHints={}",
        studentId, organized.size(), existingAssignments.size(),
        organized.stream().filter(item -> item.duplicateAssignmentId() != null &&
            !item.duplicateAssignmentId().isBlank()).count());
    return new HomeworkOrganizerDtos.Response(organized, "AI");
  }

  public HomeworkOrganizerDtos.ImageResponse organizeImage(UUID familyId, String studentId,
      HomeworkOrganizerDtos.ImageRequest request) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    String imageDataUrl = HomeworkImageInput.dataUrl(request);
    if (!model.imageAvailable()) throw new ApiExceptions.ServiceUnavailable("AI图片解析暂未配置，请使用识别图片文字");
    List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments =
        existingAssignments(familyId, studentId);
    var result = model.organizeImage(
        student, request.sourceLabel(), imageDataUrl, request.text(), existingAssignments)
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI图片解析失败，请确认模型支持图片，或点击识别图片文字"));
    log.info("homework_import image_parsed studentId={} assignments={} existingContext={} duplicateHints={}",
        studentId, result.assignments().size(), existingAssignments.size(),
        result.assignments().stream().filter(item -> item.duplicateAssignmentId() != null &&
            !item.duplicateAssignmentId().isBlank()).count());
    return result;
  }

  private List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments(
      UUID familyId, String studentId) {
    LocalDate today = LocalDate.now(BUSINESS_ZONE);
    long from = today.atStartOfDay(BUSINESS_ZONE).toInstant().toEpochMilli();
    long toInclusive = today.plusDays(7).atStartOfDay(BUSINESS_ZONE).toInstant().toEpochMilli() - 1L;
    String activeStatuses =
        "NOT_STARTED,IN_PROGRESS,PAUSED,READY_TO_SUBMIT,NEEDS_REWORK,OVERDUE";

    List<HomeworkOrganizerDtos.ExistingAssignment> result = new ArrayList<>();
    List<AssignmentDtos.Response> upcoming = assignments.list(
        familyId, studentId, null, null, from, toInclusive, activeStatuses, false);
    for (AssignmentDtos.Response item : upcoming) {
      if (result.size() >= 10) break;
      result.add(new HomeworkOrganizerDtos.ExistingAssignment(
          item.id(), item.subject(), item.title(), item.instruction(), item.textbookRef(),
          item.dueText(), item.sourceExcerpt()));
    }
    log.info("homework_import duplicate_context studentId={} horizonDays=7 selected={} evidence={}",
        studentId, result.size(),
        result.stream().filter(item -> item.sourceExcerpt() != null && !item.sourceExcerpt().isBlank()).count());
    return result;
  }
}
