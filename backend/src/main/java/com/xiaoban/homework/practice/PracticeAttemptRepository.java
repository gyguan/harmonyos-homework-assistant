package com.xiaoban.homework.practice;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticeAttemptRepository extends JpaRepository<PracticeAttemptEntity, UUID> {
  long countByFamilyIdAndStudentIdAndPaperId(UUID familyId, String studentId, String paperId);
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);
  List<PracticeAttemptEntity> findByFamilyIdAndStudentIdOrderByStartedAtDesc(UUID familyId, String studentId);
}
