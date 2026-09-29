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
  Optional<AssignmentEntity> findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotOrderByUpdatedAtDesc(
      UUID familyId, String studentId, String contentType, String status);
  Optional<AssignmentEntity>
      findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotAndDueAtGreaterThanEqualAndDueAtLessThanOrderByUpdatedAtDesc(
          UUID familyId, String studentId, String contentType, String status,
          Instant dueFrom, Instant dueTo);
  long countByFamilyIdAndStudentIdAndSubjectCodeAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
      UUID familyId, String studentId, String subjectCode, Instant from, Instant to);
  long countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
      UUID familyId, String studentId, String subjectCode, String contentType, String titlePrefix,
      Instant from, Instant to);
}
