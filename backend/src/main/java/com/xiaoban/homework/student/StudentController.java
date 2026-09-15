package com.xiaoban.homework.student;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students")
public class StudentController {
  private final StudentService service;
  public StudentController(StudentService service) { this.service = service; }

  @GetMapping
  public List<StudentDtos.Response> list(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId) { return service.list(familyId); }

  @PutMapping
  public StudentDtos.Response upsert(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @Valid @RequestBody StudentDtos.Upsert input) { return service.upsert(familyId, input); }

  @DeleteMapping("/{id}")
  public void delete(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId, @PathVariable String id) {
    service.delete(familyId, id);
  }
}
