package com.xiaoban.homework.practice;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PracticeGenerationRepository extends JpaRepository<PracticeGenerationEntity, UUID> {
  List<PracticeGenerationEntity> findByFamilyIdAndReferenceStudentId(
      UUID familyId, String referenceStudentId);

  List<PracticeGenerationEntity> findByStatusAndUpdatedAtBefore(
      String status, Instant cutoff);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select g from PracticeGenerationEntity g where g.id = :id and g.familyId = :familyId")
  Optional<PracticeGenerationEntity> lockByIdAndFamilyId(
      @Param("id") UUID id, @Param("familyId") UUID familyId);
}
