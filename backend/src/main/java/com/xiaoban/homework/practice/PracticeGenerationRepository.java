package com.xiaoban.homework.practice;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticeGenerationRepository extends JpaRepository<PracticeGenerationEntity, UUID> {
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);
}
