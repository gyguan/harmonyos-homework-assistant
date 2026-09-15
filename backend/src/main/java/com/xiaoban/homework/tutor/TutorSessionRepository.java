package com.xiaoban.homework.tutor;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TutorSessionRepository extends JpaRepository<TutorSessionEntity, UUID> {
  Optional<TutorSessionEntity> findByFamilyIdAndAssignmentId(UUID familyId, String assignmentId);
}
