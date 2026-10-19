package com.xiaoban.homework.organizer;

import com.xiaoban.homework.auth.AuthInterceptor;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/students/{studentId}/homework/source-evidence")
public class HomeworkSourceEvidenceController {
  private final HomeworkSourceEvidenceService service;
  public HomeworkSourceEvidenceController(HomeworkSourceEvidenceService service) { this.service = service; }
  @GetMapping("/{batchId}")
  public HomeworkSourceEvidenceService.Evidence get(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID family,
      @PathVariable String studentId, @PathVariable String batchId) {
    return service.get(family, studentId, batchId);
  }
}
