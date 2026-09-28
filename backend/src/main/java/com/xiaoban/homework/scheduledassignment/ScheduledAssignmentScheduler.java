package com.xiaoban.homework.scheduledassignment;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class ScheduledAssignmentScheduler {
  private static final Logger log = LoggerFactory.getLogger(ScheduledAssignmentScheduler.class);
  private final ScheduledAssignmentService service;

  public ScheduledAssignmentScheduler(ScheduledAssignmentService service) {
    this.service = service;
  }

  @Scheduled(fixedDelay = 30000)
  public void tick() {
    Instant now = Instant.now();
    List<UUID> duePlanIds = service.duePlanIds(now);
    log.info("scheduled_assignment scheduler_tick now={} duePlanCount={} duePlanIds={}",
        now, duePlanIds.size(), duePlanIds);
    for (UUID planId : duePlanIds) {
      log.info("scheduled_assignment scheduler_dispatch planId={} now={}", planId, now);
      try {
        service.executeDuePlan(planId, now);
      } catch (RuntimeException error) {
        log.error("scheduled_assignment scheduler_unhandled_error planId={} now={} errorType={} message={}",
            planId, now, error.getClass().getSimpleName(), error.getMessage(), error);
      }
    }
  }
}
