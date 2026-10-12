package com.xiaoban.homework.mediasync;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class AssignmentMediaSyncWorker {
  private final AssignmentMediaSyncService service;
  private final AssignmentMediaSyncAiAnalyzer aiAnalyzer;

  public AssignmentMediaSyncWorker(
      AssignmentMediaSyncService service,
      AssignmentMediaSyncAiAnalyzer aiAnalyzer) {
    this.service = service;
    this.aiAnalyzer = aiAnalyzer;
  }

  public void process(UUID syncId) {
    if (!service.claim(syncId, Instant.now())) return;
    try {
      AssignmentMediaSyncService.TimelineBuildResult result = aiAnalyzer.canAnalyze(syncId)
          ? aiAnalyzer.analyze(syncId)
          : service.buildStubTimeline(syncId);
      service.complete(syncId, result, Instant.now());
    } catch (RuntimeException error) {
      service.fail(syncId, Instant.now(), error);
    }
  }
}
