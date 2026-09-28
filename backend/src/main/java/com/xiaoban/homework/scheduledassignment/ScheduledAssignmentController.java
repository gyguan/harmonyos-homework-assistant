package com.xiaoban.homework.scheduledassignment;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
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
public class ScheduledAssignmentController {
  private final ScheduledAssignmentService service;

  public ScheduledAssignmentController(ScheduledAssignmentService service) {
    this.service = service;
  }

  @GetMapping("/scheduled-assignment-plans")
  public List<ScheduledAssignmentDtos.PlanResponse> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @RequestParam String studentId) {
    return service.list(familyId, studentId);
  }

  @PostMapping("/students/{studentId}/scheduled-assignment-plans")
  public ScheduledAssignmentDtos.PlanResponse create(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @Valid @RequestBody ScheduledAssignmentDtos.UpsertRequest input) {
    return service.create(familyId, studentId, input);
  }

  @PutMapping("/scheduled-assignment-plans/{planId}")
  public ScheduledAssignmentDtos.PlanResponse update(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID planId,
      @Valid @RequestBody ScheduledAssignmentDtos.UpdateRequest input) {
    return service.update(familyId, planId, input);
  }

  @PostMapping("/scheduled-assignment-plans/{planId}/actions")
  public ScheduledAssignmentDtos.PlanResponse action(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID planId,
      @Valid @RequestBody ScheduledAssignmentDtos.ActionRequest input) {
    return service.action(familyId, planId, input);
  }

  @DeleteMapping("/scheduled-assignment-plans/{planId}")
  public void delete(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID planId) {
    service.delete(familyId, planId);
  }

  @GetMapping("/scheduled-assignment-plans/{planId}/runs")
  public List<ScheduledAssignmentDtos.RunResponse> runs(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID planId) {
    return service.runs(familyId, planId);
  }
}
