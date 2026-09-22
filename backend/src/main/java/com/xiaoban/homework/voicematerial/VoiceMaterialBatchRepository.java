package com.xiaoban.homework.voicematerial;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface VoiceMaterialBatchRepository extends JpaRepository<VoiceMaterialBatchEntity, UUID> {
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);

  @Query("""
      select b.studentId from VoiceMaterialBatchEntity b
      where b.familyId = :familyId and b.id = :batchId
      """)
  Optional<String> findOwnedStudentId(
      @Param("familyId") UUID familyId, @Param("batchId") UUID batchId);
}
