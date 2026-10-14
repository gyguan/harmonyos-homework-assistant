package com.xiaoban.homework.assignment;

import java.time.Instant;
import java.time.LocalDate;
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
      findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotAndTaskDateOrderByUpdatedAtDesc(
          UUID familyId, String studentId, String contentType, String status, LocalDate taskDate);
  long countByFamilyIdAndStudentIdAndSubjectCodeAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
      UUID familyId, String studentId, String subjectCode, Instant from, Instant to);
  long countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
      UUID familyId, String studentId, String subjectCode, String contentType, String titlePrefix,
      Instant from, Instant to);
  /**
   * 与上一个方法同义，但把某个任务排除在计数之外。
   *
   * <p>顺延要给同一条任务重算名称，如果把它自己也数进去，明明没有同名的第二条任务，
   * 名称也会被追加成「… ②」。
   */
  long countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThanAndIdNot(
      UUID familyId, String studentId, String subjectCode, String contentType, String titlePrefix,
      Instant from, Instant to, String excludedAssignmentId);
}
