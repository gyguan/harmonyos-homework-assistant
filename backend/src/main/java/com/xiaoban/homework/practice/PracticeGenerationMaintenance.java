package com.xiaoban.homework.practice;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class PracticeGenerationMaintenance {
  public static final Duration STALE_AFTER = Duration.ofMinutes(15);
  private static final Logger log = LoggerFactory.getLogger(PracticeGenerationMaintenance.class);

  private final PracticeGenerationRepository generations;

  public PracticeGenerationMaintenance(PracticeGenerationRepository generations) {
    this.generations = generations;
  }

  @Scheduled(fixedDelay = 600000)
  @Transactional
  public void recoverStaleGenerating() {
    Instant now = Instant.now();
    List<PracticeGenerationEntity> stale =
        generations.findByStatusAndUpdatedAtBefore("GENERATING", now.minus(STALE_AFTER));
    if (stale.isEmpty()) return;

    for (PracticeGenerationEntity generation : stale) {
      generation.status = "FAILED";
      generation.errorMessage = "AI生成过程异常中断，可重新生成";
      generation.updatedAt = now;
    }
    generations.saveAll(stale);
    log.warn("practice_generation recovered_stale count={}", stale.size());
  }
}
