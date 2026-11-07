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
@RequestMapping("/api/v1/students/{studentId}/homework/teachers")
public class HomeworkStudentTeacherController {
  private final HomeworkStudentTeacherService service;
  public HomeworkStudentTeacherController(HomeworkStudentTeacherService service) {
    this.service = service;
  }
  @GetMapping
  public List<HomeworkStudentTeacherService.TeacherResult> list(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId) {
    return service.list(familyId, studentId);
  }
  @PostMapping
  public HomeworkStudentTeacherService.TeacherResult register(
      @RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String studentId,
      @Valid @RequestBody HomeworkStudentTeacherService.TeacherInput input) {
    return service.register(familyId, studentId, input);
  }
}
