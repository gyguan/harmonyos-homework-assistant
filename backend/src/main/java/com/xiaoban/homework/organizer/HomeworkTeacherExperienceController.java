package com.xiaoban.homework.organizer;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students/{studentId}/homework/teacher-experiences")
public class HomeworkTeacherExperienceController {
  private final HomeworkTeacherExperienceService service;

  public HomeworkTeacherExperienceController(HomeworkTeacherExperienceService service) {
    this.service = service;
  }

  @GetMapping
  public List<HomeworkTeacherExperienceDtos.Response> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId) {
    return service.list(familyId, studentId);
  }

  @PostMapping
  public HomeworkTeacherExperienceDtos.Response upsert(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId,
      @Valid @RequestBody HomeworkTeacherExperienceDtos.Upsert request) {
    return service.upsert(familyId, studentId, request);
  }

  @PostMapping("/confirmed-edit")
  public void confirmedEdit(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId,
      @Valid @RequestBody HomeworkTeacherExperienceDtos.ConfirmedEdit request) {
    service.confirmedEdit(familyId, studentId, request);
  }

  @PutMapping("/{id}/active")
  public HomeworkTeacherExperienceDtos.Response setActive(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId,
      @PathVariable UUID id, @Valid @RequestBody HomeworkTeacherExperienceDtos.ActiveUpdate request) {
    return service.setActive(familyId, studentId, id, request.active());
  }

  @DeleteMapping("/{id}")
  public void delete(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId, @PathVariable UUID id) {
    service.delete(familyId, studentId, id);
  }
}
