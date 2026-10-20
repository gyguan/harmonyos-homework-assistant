package com.xiaoban.homework.organizer;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeworkSourceEvidenceRepository extends JpaRepository<HomeworkSourceEvidenceEntity, UUID> {
  Optional<HomeworkSourceEvidenceEntity> findByFamilyIdAndStudentIdAndBatchId(UUID familyId, String studentId, String batchId);
}
