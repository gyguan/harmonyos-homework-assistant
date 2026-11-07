package com.xiaoban.homework.organizer;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students/{studentId}/homework/feedback")
public class HomeworkOrganizerFeedbackController {
  private final HomeworkOrganizerFeedbackService service;

  public HomeworkOrganizerFeedbackController(HomeworkOrganizerFeedbackService service) {
    this.service = service;
  }

  @GetMapping("/types")
  public List<HomeworkOrganizerFeedbackDtos.TypeResponse> types(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId) {
    return service.types(familyId, studentId);
  }

  @GetMapping
  public List<HomeworkOrganizerFeedbackDtos.Response> history(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId) {
    return service.history(familyId, studentId);
  }

  @PostMapping("/{feedbackId}/promote")
  public HomeworkTeacherExperienceDtos.Response promote(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId, @PathVariable UUID feedbackId,
      @Valid @RequestBody HomeworkOrganizerFeedbackDtos.Promote request) {
    return service.promote(familyId, studentId, feedbackId, request);
  }

  @PostMapping
  public HomeworkOrganizerFeedbackDtos.Response submit(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId,
      @Valid @RequestBody HomeworkOrganizerFeedbackDtos.Create request) {
    return service.submit(familyId, studentId, request);
  }
}
