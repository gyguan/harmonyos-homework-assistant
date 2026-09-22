package com.xiaoban.homework.voicematerial;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VoiceMaterialBatchRepository extends JpaRepository<VoiceMaterialBatchEntity, UUID> {
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);
}
