package com.xiaoban.homework.organizer;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students/{studentId}/homework/review-differences")
public class HomeworkOrganizerReviewDifferenceController {
  private final HomeworkOrganizerReviewDifferenceService service;
  public HomeworkOrganizerReviewDifferenceController(HomeworkOrganizerReviewDifferenceService service) {
    this.service = service;
  }
  @PostMapping
  public HomeworkOrganizerReviewDifferenceService.Result save(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId,
      @Valid @RequestBody HomeworkOrganizerReviewDifferenceService.Review request) {
    return service.save(familyId, studentId, request);
  }
  @GetMapping("/summary")
  public List<HomeworkOrganizerReviewDifferenceService.Summary> summary(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId) {
    return service.summary(familyId, studentId);
  }

  @GetMapping
  public List<HomeworkOrganizerReviewDifferenceService.History> history(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId) {
    return service.history(familyId, studentId);
  }
}
