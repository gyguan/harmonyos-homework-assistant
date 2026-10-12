package com.xiaoban.homework.mediasync;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class AssignmentMediaSyncScheduler {
  private static final Logger log = LoggerFactory.getLogger(AssignmentMediaSyncScheduler.class);
  private final AssignmentMediaSyncService service;
  private final AssignmentMediaSyncWorker worker;

  public AssignmentMediaSyncScheduler(AssignmentMediaSyncService service, AssignmentMediaSyncWorker worker) {
    this.service = service;
    this.worker = worker;
  }

  @Scheduled(fixedDelayString = "${app.media-sync.worker-delay-ms:5000}")
  public void tick() {
    Instant now = Instant.now();
    service.recoverStaleRunning(now.minusSeconds(300), now);
    List<UUID> due = service.dueJobIds(now);
    if (due.isEmpty()) return;

    log.info("media_sync scheduler_tick dueJobCount={} dueJobIds={}", due.size(), due);
    for (UUID syncId : due) {
      try {
        worker.process(syncId);
      } catch (RuntimeException error) {
        log.error("media_sync scheduler_unhandled_error syncId={} errorType={} message={}",
            syncId, error.getClass().getSimpleName(), error.getMessage(), error);
      }
    }
  }
}
