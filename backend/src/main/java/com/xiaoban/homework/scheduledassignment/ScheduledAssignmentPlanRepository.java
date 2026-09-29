package com.xiaoban.homework.scheduledassignment;

import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ScheduledAssignmentPlanRepository
    extends JpaRepository<ScheduledAssignmentPlanEntity, UUID> {
  Optional<ScheduledAssignmentPlanEntity> findByIdAndFamilyId(UUID id, UUID familyId);

  List<ScheduledAssignmentPlanEntity> findByFamilyIdAndStudentIdOrderByCreatedAtDesc(
      UUID familyId, String studentId);

  List<ScheduledAssignmentPlanEntity>
      findByFamilyIdAndStudentIdAndPlanTypeOrderByCreatedAtDesc(
          UUID familyId, String studentId, String planType);

  List<ScheduledAssignmentPlanEntity>
      findByStatusAndNextFireAtLessThanEqualOrderByNextFireAtAsc(
          String status, Instant now);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select p from scheduled_assignment_plan p where p.id = :id")
  Optional<ScheduledAssignmentPlanEntity> lockById(@Param("id") UUID id);
}
