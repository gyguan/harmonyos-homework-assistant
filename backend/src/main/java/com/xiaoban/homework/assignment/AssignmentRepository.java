package com.xiaoban.homework.assignment;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface AssignmentRepository extends JpaRepository<AssignmentEntity, String>,
    JpaSpecificationExecutor<AssignmentEntity> {
  List<AssignmentEntity> findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(UUID familyId, String studentId);
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);
  boolean existsByFamilyIdAndStudentIdAndContentType(UUID familyId, String studentId, String contentType);
  Optional<AssignmentEntity> findFirstByFamilyIdAndStudentIdAndContentTypeOrderByUpdatedAtDesc(
      UUID familyId, String studentId, String contentType);
  long countByFamilyIdAndStudentIdAndSubjectCodeAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
      UUID familyId, String studentId, String subjectCode, Instant from, Instant to);
}
