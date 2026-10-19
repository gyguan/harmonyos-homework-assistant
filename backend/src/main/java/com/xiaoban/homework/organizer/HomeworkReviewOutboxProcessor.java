package com.xiaoban.homework.organizer;

import java.time.Instant;
import java.util.Arrays;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeworkReviewOutboxProcessor {
  private static final Logger log = LoggerFactory.getLogger(HomeworkReviewOutboxProcessor.class);
  private final HomeworkReviewOutboxRepository outbox;
  private final HomeworkOrganizerReviewDifferenceService reviews;

  public HomeworkReviewOutboxProcessor(HomeworkReviewOutboxRepository outbox,
      HomeworkOrganizerReviewDifferenceService reviews) {
    this.outbox = outbox;
    this.reviews = reviews;
  }

  @Transactional
  public void process(UUID id) {
    var row = outbox.lockById(id).orElse(null);
    if (row == null || !"PENDING".equals(row.status)
        || row.nextAttemptAt.isAfter(Instant.now())) return;
    try {
      var ids = Arrays.asList(row.candidateIds.split("\n"));
      reviews.finalizePublished(row.familyId, row.studentId,
          new HomeworkOrganizerReviewDifferenceService.Finalize(row.batchId, ids));
      row.status = "COMPLETED";
      row.lastError = "";
      row.updatedAt = Instant.now();
      outbox.save(row);
      log.info("homework_review_outbox completed batchId={} attempts={}", row.batchId, row.attempts + 1);
    } catch (RuntimeException error) {
      row.attempts++;
      // Bounded retry and exponential backoff: 30, 60, 120, ... 3600 seconds.
      if (row.attempts >= 8) {
        row.status = "FAILED";
      } else {
        long delay = Math.min(3600L, 30L << Math.min(7, row.attempts - 1));
        row.nextAttemptAt = Instant.now().plusSeconds(delay);
      }
      row.lastError = error.getClass().getSimpleName();
      row.updatedAt = Instant.now();
      outbox.save(row);
      log.warn("homework_review_outbox retry batchId={} status={} attempts={} exception={}",
          row.batchId, row.status, row.attempts, row.lastError);
    }
  }
}
