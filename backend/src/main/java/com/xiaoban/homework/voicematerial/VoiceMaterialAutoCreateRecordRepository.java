package com.xiaoban.homework.voicematerial;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VoiceMaterialAutoCreateRecordRepository
    extends JpaRepository<VoiceMaterialAutoCreateRecordEntity, UUID> {
  Optional<VoiceMaterialAutoCreateRecordEntity> findByFamilyIdAndStudentIdAndBusinessDate(
      UUID familyId, String studentId, LocalDate businessDate);
}
