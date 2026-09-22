package com.xiaoban.homework.media;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MediaAssetRepository extends JpaRepository<MediaAssetEntity, UUID> {
  Optional<MediaAssetEntity> findByFamilyIdAndSha256AndSizeBytes(
      UUID familyId, String sha256, long sizeBytes);
}
