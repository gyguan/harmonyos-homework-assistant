package com.xiaoban.homework.mediasync;

import com.xiaoban.homework.auth.AuthInterceptor;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/assignments")
public class AssignmentMediaSyncController {
  private final AssignmentMediaSyncService service;

  public AssignmentMediaSyncController(AssignmentMediaSyncService service) {
    this.service = service;
  }

  @GetMapping("/{assignmentId}/media-sync")
  public AssignmentMediaSyncDtos.Response get(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId) {
    return service.get(familyId, assignmentId);
  }
}
