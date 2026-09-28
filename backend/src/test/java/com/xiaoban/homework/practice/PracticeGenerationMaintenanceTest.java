package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PracticeGenerationMaintenanceTest {
  @Test
  void staleGeneratingRecordBecomesFailed() {
    PracticeGenerationRepository generations = mock(PracticeGenerationRepository.class);
    PracticeGenerationEntity generation = new PracticeGenerationEntity();
    generation.id = UUID.randomUUID();
    generation.status = "GENERATING";
    generation.updatedAt = Instant.now().minus(30, java.time.temporal.ChronoUnit.MINUTES);
    when(generations.findByStatusAndUpdatedAtBefore(
        org.mockito.ArgumentMatchers.eq("GENERATING"),
        org.mockito.ArgumentMatchers.any(Instant.class)))
        .thenReturn(List.of(generation));

    new PracticeGenerationMaintenance(generations).recoverStaleGenerating();

    assertEquals("FAILED", generation.status);
    assertEquals("AI生成过程异常中断，可重新生成", generation.errorMessage);
    verify(generations).saveAll(List.of(generation));
  }
}
