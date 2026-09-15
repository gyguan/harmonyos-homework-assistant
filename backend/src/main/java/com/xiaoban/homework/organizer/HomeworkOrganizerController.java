package com.xiaoban.homework.organizer;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students/{studentId}/homework")
public class HomeworkOrganizerController {
  private final HomeworkOrganizerService service;

  public HomeworkOrganizerController(HomeworkOrganizerService service) {
    this.service = service;
  }

  @PostMapping("/organize")
  public HomeworkOrganizerDtos.Response organize(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @Valid @RequestBody HomeworkOrganizerDtos.Request request) {
    return service.organize(familyId, studentId, request);
  }
}
