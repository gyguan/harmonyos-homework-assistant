package com.xiaoban.homework.student;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class StudentService {
  private final StudentRepository repository;
  public StudentService(StudentRepository repository) { this.repository = repository; }

  @Transactional(readOnly = true)
  public List<StudentDtos.Response> list(UUID familyId) {
    return repository.findByFamilyIdOrderByCreatedAt(familyId).stream().map(StudentDtos.Response::from).toList();
  }

  @Transactional
  public StudentDtos.Response upsert(UUID familyId, StudentDtos.Upsert input) {
    StudentEntity entity = repository.findById(input.id()).orElseGet(StudentEntity::new);
    if (entity.familyId != null && !familyId.equals(entity.familyId)) throw new ApiExceptions.Conflict("孩子 ID 已属于其他家庭");
    Instant now = Instant.now();
    if (entity.createdAt == null) entity.createdAt = now;
    entity.id = input.id(); entity.familyId = familyId; entity.name = input.name(); entity.grade = input.grade();
    entity.className = input.className(); entity.semester = input.semester();
    entity.textbookSummary = input.textbookSummary() == null ? "" : input.textbookSummary(); entity.updatedAt = now;
    return StudentDtos.Response.from(repository.save(entity));
  }

  @Transactional(readOnly = true)
  public StudentEntity requireOwned(UUID familyId, String id) {
    StudentEntity student = repository.findById(id).orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    return student;
  }
}
