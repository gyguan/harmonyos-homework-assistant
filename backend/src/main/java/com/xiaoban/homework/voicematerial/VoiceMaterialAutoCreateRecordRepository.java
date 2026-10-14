package com.xiaoban.homework.voicematerial;

import java.time.LocalDate;
import java.util.Collection;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VoiceMaterialAutoCreateRecordRepository
    extends JpaRepository<VoiceMaterialAutoCreateRecordEntity, UUID> {
  Optional<VoiceMaterialAutoCreateRecordEntity> findByFamilyIdAndStudentIdAndBusinessDate(
      UUID familyId, String studentId, LocalDate businessDate);

  /**
   * voice_material_auto_create_record.package_id 的外键没有 on delete cascade，
   * 删素材目录前必须先清掉这些记录，否则会因外键约束直接失败。
   */
  long deleteByFamilyIdAndPackageIdIn(UUID familyId, Collection<UUID> packageIds);
}
