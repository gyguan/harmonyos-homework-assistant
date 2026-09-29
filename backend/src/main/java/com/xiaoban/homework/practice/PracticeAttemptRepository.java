package com.xiaoban.homework.practice;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticeAttemptRepository extends JpaRepository<PracticeAttemptEntity, UUID> {
  long countByFamilyIdAndStudentIdAndPaperId(UUID familyId, String studentId, String paperId);
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);
  java.util.Optional<PracticeAttemptEntity>
      findFirstByFamilyIdAndStudentIdAndPaperIdAndPaperVersionAndSourceAttemptIdAndStatusOrderByStartedAtDesc(
          UUID familyId, String studentId, String paperId, int paperVersion, UUID sourceAttemptId, String status);
  List<PracticeAttemptEntity> findByFamilyIdAndStudentIdOrderByStartedAtDesc(UUID familyId, String studentId);
}
