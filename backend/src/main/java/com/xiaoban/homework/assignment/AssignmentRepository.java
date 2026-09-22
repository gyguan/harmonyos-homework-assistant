package com.xiaoban.homework.assignment;

import java.util.List;
import java.util.UUID;
import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface AssignmentRepository extends JpaRepository<AssignmentEntity, String>,
    JpaSpecificationExecutor<AssignmentEntity> {
  List<AssignmentEntity> findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(UUID familyId, String studentId);
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);
  long countByFamilyIdAndStudentIdAndSubjectCodeAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
      UUID familyId, String studentId, String subjectCode, Instant from, Instant to);
}
