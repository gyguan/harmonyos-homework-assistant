package com.xiaoban.homework.scheduledassignment;

import java.time.Instant;
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
    for (UUID planId : service.duePlanIds(now)) {
      try {
        service.executeDuePlan(planId, now);
      } catch (RuntimeException error) {
        log.error("Scheduled assignment execution failed for plan {}", planId, error);
      }
    }
  }
}
