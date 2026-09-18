package com.xiaoban.homework.submission;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubmissionRepository extends JpaRepository<SubmissionEntity, UUID> {
  List<SubmissionEntity> findByFamilyIdAndAssignmentIdOrderBySubmittedAtDesc(UUID familyId, String assignmentId);
  Optional<SubmissionEntity> findFirstByFamilyIdAndAssignmentIdOrderBySubmittedAtDesc(
      UUID familyId, String assignmentId);
}
