package com.xiaoban.homework.mediasync;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class AssignmentMediaSyncEventListener {
  private static final Logger log = LoggerFactory.getLogger(AssignmentMediaSyncEventListener.class);
  private final AssignmentMediaSyncService service;

  public AssignmentMediaSyncEventListener(AssignmentMediaSyncService service) {
    this.service = service;
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
  public void onResourcesReady(AssignmentResourcesReadyEvent event) {
    try {
      service.ensureMediaSyncJob(event.familyId(), event.assignmentId());
    } catch (RuntimeException error) {
      log.warn("media_sync job_create_failed assignmentId={} errorType={} message={}",
          event.assignmentId(), error.getClass().getSimpleName(), error.getMessage());
    }
  }
}
