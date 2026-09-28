package com.xiaoban.homework.practice;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class PracticeGenerationController {
  private final PracticeGenerationService service;

  public PracticeGenerationController(PracticeGenerationService service) {
    this.service = service;
  }

  @PostMapping("/students/{studentId}/practice/generations")
  public PracticeGenerationDtos.GenerationResponse generate(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId,
      @Valid @RequestBody PracticeGenerationDtos.GenerateRequest input) {
    return service.generate(familyId, studentId, input);
  }

  @GetMapping("/practice/generations/{generationId}")
  public PracticeGenerationDtos.GenerationResponse get(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID generationId) {
    return service.get(familyId, generationId);
  }

  @PostMapping("/practice/generations/{generationId}/publish")
  public PracticeGenerationDtos.PublishResponse publish(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable UUID generationId) {
    return service.publish(familyId, generationId);
  }
}
