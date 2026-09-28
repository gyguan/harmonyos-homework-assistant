package com.xiaoban.homework.scheduledassignment;

import java.time.Instant;
import java.util.UUID;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class ScheduledAssignmentScheduler {
  private final ScheduledAssignmentService service;

  public ScheduledAssignmentScheduler(ScheduledAssignmentService service) {
    this.service = service;
  }

  @Scheduled(fixedDelay = 30000)
  public void tick() {
    Instant now = Instant.now();
    for (UUID planId : service.duePlanIds(now)) {
      service.executeDuePlan(planId, now);
    }
  }
}
