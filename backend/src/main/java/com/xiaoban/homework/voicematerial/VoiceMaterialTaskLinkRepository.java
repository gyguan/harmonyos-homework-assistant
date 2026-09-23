package com.xiaoban.homework.voicematerial;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface VoiceMaterialTaskLinkRepository
    extends JpaRepository<VoiceMaterialTaskLinkEntity, String> {
  Optional<VoiceMaterialTaskLinkEntity> findByFamilyIdAndRequestId(UUID familyId, String requestId);
  Optional<VoiceMaterialTaskLinkEntity> findByFamilyIdAndAssignmentId(UUID familyId, String assignmentId);
  Optional<VoiceMaterialTaskLinkEntity> findFirstByFamilyIdAndPackageIdOrderByCreatedAtDesc(
      UUID familyId, UUID packageId);
  List<VoiceMaterialTaskLinkEntity> findByFamilyIdAndStudentIdOrderByCreatedAtDesc(
      UUID familyId, String studentId);
  boolean existsByFamilyIdAndPackageId(UUID familyId, UUID packageId);

  @Query("""
      select count(l) from VoiceMaterialTaskLinkEntity l
      where l.familyId = :familyId and l.packageId = :packageId
      """)
  long countUsage(@Param("familyId") UUID familyId, @Param("packageId") UUID packageId);

  @Query("""
      select count(l) from VoiceMaterialTaskLinkEntity l
      where l.familyId = :familyId and l.packageId = :packageId
        and exists (
          select a.id from assignment a
          where a.id = l.assignmentId
            and a.familyId = :familyId
            and a.status <> 'COMPLETED'
        )
      """)
  long countActiveUsage(@Param("familyId") UUID familyId, @Param("packageId") UUID packageId);
}
