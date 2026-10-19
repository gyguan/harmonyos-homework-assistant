package com.xiaoban.homework.organizer;

import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@EnableScheduling
public class HomeworkReviewOutboxWorker {
  private static final Logger log = LoggerFactory.getLogger(HomeworkReviewOutboxWorker.class);
  private final HomeworkReviewOutboxRepository outbox;
  private final HomeworkReviewOutboxProcessor processor;

  public HomeworkReviewOutboxWorker(HomeworkReviewOutboxRepository outbox,
      HomeworkReviewOutboxProcessor processor) {
    this.outbox = outbox;
    this.processor = processor;
  }

  @Scheduled(fixedDelayString = "${app.homework-review.worker-delay-ms:30000}")
  public void drain() {
    for (var pending : outbox.findTop20ByStatusAndNextAttemptAtLessThanEqualOrderByNextAttemptAtAsc(
        "PENDING", Instant.now())) {
      try {
        processor.process(pending.id);
      } catch (RuntimeException error) {
        // A transaction/connection failure should be retried on the next scheduler pass.
        log.warn("homework_review_outbox worker_exception={} id={}",
            error.getClass().getSimpleName(), pending.id);
      }
    }
  }
}
