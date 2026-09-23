package com.xiaoban.homework.voicematerial;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VoiceMaterialTaskLinkRepository
    extends JpaRepository<VoiceMaterialTaskLinkEntity, String> {
  Optional<VoiceMaterialTaskLinkEntity> findByFamilyIdAndRequestId(UUID familyId, String requestId);
  Optional<VoiceMaterialTaskLinkEntity> findByFamilyIdAndAssignmentId(UUID familyId, String assignmentId);
  Optional<VoiceMaterialTaskLinkEntity> findFirstByFamilyIdAndPackageIdOrderByCreatedAtDesc(
      UUID familyId, UUID packageId);
  List<VoiceMaterialTaskLinkEntity> findByFamilyIdAndStudentIdOrderByCreatedAtDesc(
      UUID familyId, String studentId);
  boolean existsByFamilyIdAndPackageId(UUID familyId, UUID packageId);
}
