package com.xiaoban.homework.assignment;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class AssignmentController {
  private static final ZoneId DEFAULT_ZONE = ZoneId.of("Asia/Shanghai");
  private final AssignmentService service;
  private final AssignmentReviewService reviewService;
  private final AssignmentBatchPublishService batchPublishService;

  public AssignmentController(AssignmentService service, AssignmentReviewService reviewService,
      AssignmentBatchPublishService batchPublishService) {
    this.service = service;
    this.reviewService = reviewService;
    this.batchPublishService = batchPublishService;
  }

  @GetMapping("/students/{studentId}/assignments")
  public List<AssignmentDtos.Response> list(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @RequestParam(required = false) String type,
      @RequestParam(required = false) String subjectCode,
      @RequestParam(required = false) Long from,
      @RequestParam(required = false) Long to,
      @RequestParam(required = false) String status,
      @RequestParam(required = false) Boolean undated) {
    return service.list(familyId, studentId, type, subjectCode, from, to, status, undated);
  }

  @GetMapping("/students/{studentId}/assignments/summary")
  public AssignmentDtos.TodaySummary todaySummary(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId, @RequestParam(required = false) LocalDate date) {
    return service.todaySummary(familyId, studentId, date == null ? LocalDate.now(DEFAULT_ZONE) : date);
  }

  @PostMapping("/students/{studentId}/assignments")
  public AssignmentDtos.Response create(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId, @Valid @RequestBody AssignmentDtos.Create input) {
    return service.create(familyId, studentId, input);
  }

  @PostMapping("/students/{studentId}/assignments/batch")
  public AssignmentDtos.BatchCreateResponse batchCreate(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @Valid @RequestBody AssignmentDtos.BatchCreateRequest input) {
    return batchPublishService.publish(familyId, studentId, input);
  }

  @PostMapping("/assignments/{id}/actions")
  public AssignmentDtos.Response action(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String id, @Valid @RequestBody AssignmentDtos.ActionRequest input) {
    return service.action(familyId, id, input);
  }

  @PostMapping("/assignments/{id}/review")
  public AssignmentDtos.Response review(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String id, @Valid @RequestBody AssignmentDtos.ReviewRequest input) {
    return reviewService.review(familyId, id, input);
  }

  @PatchMapping("/assignments/{id}")
  public AssignmentDtos.Response update(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String id, @Valid @RequestBody AssignmentDtos.Update input) {
    return service.update(familyId, id, input);
  }

  @PutMapping("/assignments/{id}")
  public AssignmentDtos.Response updateCompatible(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String id, @Valid @RequestBody AssignmentDtos.Update input) {
    return service.update(familyId, id, input);
  }

  @DeleteMapping("/assignments/{id}")
  public void delete(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String id) {
    service.delete(familyId, id);
  }
}
