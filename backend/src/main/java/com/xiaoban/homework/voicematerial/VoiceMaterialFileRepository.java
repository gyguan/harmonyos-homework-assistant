package com.xiaoban.homework.voicematerial;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VoiceMaterialFileRepository extends JpaRepository<VoiceMaterialFileEntity, UUID> {
  List<VoiceMaterialFileEntity> findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
      UUID familyId, UUID packageId);
  boolean existsByAssetId(UUID assetId);
  Optional<VoiceMaterialFileEntity> findByFamilyIdAndPackageIdAndResourceTypeAndRelativeName(
      UUID familyId, UUID packageId, String resourceType, String relativeName);
}
