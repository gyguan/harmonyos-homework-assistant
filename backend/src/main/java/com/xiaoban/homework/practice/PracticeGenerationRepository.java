package com.xiaoban.homework.practice;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticeGenerationRepository extends JpaRepository<PracticeGenerationEntity, UUID> {
  boolean existsByFamilyIdAndReferenceStudentId(UUID familyId, String referenceStudentId);
}
