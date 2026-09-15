package com.xiaoban.homework.assignment;

import com.xiaoban.homework.auth.AuthInterceptor;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class AssignmentController {
  private final AssignmentService service;
  public AssignmentController(AssignmentService service) { this.service = service; }

  @GetMapping("/students/{studentId}/assignments")
  public List<AssignmentDtos.Response> list(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId) { return service.list(familyId, studentId); }

  @PostMapping("/students/{studentId}/assignments")
  public AssignmentDtos.Response create(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String studentId, @Valid @RequestBody AssignmentDtos.Create input) { return service.create(familyId, studentId, input); }

  @PatchMapping("/assignments/{id}")
  public AssignmentDtos.Response update(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String id, @Valid @RequestBody AssignmentDtos.Update input) { return service.update(familyId, id, input); }

  @PutMapping("/assignments/{id}")
  public AssignmentDtos.Response updateCompatible(@RequestAttribute(AuthInterceptor.FAMILY_ID) UUID familyId,
      @PathVariable String id, @Valid @RequestBody AssignmentDtos.Update input) { return service.update(familyId, id, input); }
}
