package com.xiaoban.homework.voicematerial;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface VoiceMaterialPackageRepository extends JpaRepository<VoiceMaterialPackageEntity, UUID> {
  List<VoiceMaterialPackageEntity> findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
      UUID familyId, String studentId);

  Optional<VoiceMaterialPackageEntity> findByFamilyIdAndStudentIdAndPackageFingerprint(
      UUID familyId, String studentId, String packageFingerprint);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("""
      select p from VoiceMaterialPackageEntity p
      where p.familyId = :familyId
        and p.studentId = :studentId
        and p.status = 'READY'
      order by p.directoryName asc, p.createdAt asc, p.id asc
      """)
  List<VoiceMaterialPackageEntity> lockNextReady(
      @Param("familyId") UUID familyId,
      @Param("studentId") String studentId,
      Pageable pageable);
}
