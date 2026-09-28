package com.xiaoban.homework.scheduledassignment;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScheduledAssignmentRunRepository
    extends JpaRepository<ScheduledAssignmentRunEntity, UUID> {
  Optional<ScheduledAssignmentRunEntity> findByPlanIdAndScheduledFireAt(
      UUID planId, Instant scheduledFireAt);

  List<ScheduledAssignmentRunEntity> findTop20ByPlanIdOrderByScheduledFireAtDesc(UUID planId);
}
