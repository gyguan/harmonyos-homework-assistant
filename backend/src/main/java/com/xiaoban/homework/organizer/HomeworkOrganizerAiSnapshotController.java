package com.xiaoban.homework.organizer;

import com.xiaoban.homework.auth.AuthInterceptor;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students/{studentId}/homework/ai-snapshots")
public class HomeworkOrganizerAiSnapshotController {
  private final HomeworkOrganizerAiSnapshotService service;
  public HomeworkOrganizerAiSnapshotController(HomeworkOrganizerAiSnapshotService service) {
    this.service = service;
  }
  @GetMapping("/{batchId}")
  public List<HomeworkOrganizerAiSnapshotService.Candidate> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId, @PathVariable String batchId) {
    return service.list(familyId, studentId, batchId);
  }
}
