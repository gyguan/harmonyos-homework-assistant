package com.xiaoban.homework.mediasync;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class AssignmentMediaSyncWorker {
  private final AssignmentMediaSyncService service;

  public AssignmentMediaSyncWorker(AssignmentMediaSyncService service) {
    this.service = service;
  }

  public void process(UUID syncId) {
    if (!service.claim(syncId, Instant.now())) return;
    try {
      AssignmentMediaSyncService.TimelineBuildResult result = service.buildStubTimeline(syncId);
      service.complete(syncId, result, Instant.now());
    } catch (RuntimeException error) {
      service.fail(syncId, Instant.now(), error);
    }
  }
}
