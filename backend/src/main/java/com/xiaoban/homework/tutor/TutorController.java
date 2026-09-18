package com.xiaoban.homework.tutor;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/assignments/{assignmentId}/tutor")
public class TutorController {
  private final TutorService service;
  public TutorController(TutorService service) { this.service = service; }

  @GetMapping
  public TutorDtos.Conversation conversation(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId,
      @RequestParam(required = false) Long before,
      @RequestParam(defaultValue = "40") int limit) {
    return service.conversation(familyId, assignmentId, before, limit);
  }

  @PostMapping("/messages")
  public TutorDtos.Conversation ask(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String assignmentId, @Valid @RequestBody TutorDtos.AskRequest request) {
    return service.ask(familyId, assignmentId, request);
  }
}
