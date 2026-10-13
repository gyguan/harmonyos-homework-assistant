package com.xiaoban.homework.coverage;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DailyHomeworkCoverageRepository
    extends JpaRepository<DailyHomeworkCoverageEntity, UUID> {
  List<DailyHomeworkCoverageEntity> findByFamilyIdAndStudentIdAndTaskDateOrderByUpdatedAtDesc(
      UUID familyId, String studentId, LocalDate taskDate);

  void deleteByFamilyIdAndStudentIdAndTaskDateAndAccountIdAndParentIdentity(
      UUID familyId, String studentId, LocalDate taskDate, UUID accountId, String parentIdentity);
}
