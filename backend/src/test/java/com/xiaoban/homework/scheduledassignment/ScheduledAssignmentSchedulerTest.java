package com.xiaoban.homework.scheduledassignment;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ScheduledAssignmentSchedulerTest {
  @Test
  void onePlanFailureDoesNotBlockLaterPlansInSameTick() {
    ScheduledAssignmentService service = mock(ScheduledAssignmentService.class);
    UUID first = UUID.randomUUID();
    UUID second = UUID.randomUUID();
    when(service.duePlanIds(any(Instant.class))).thenReturn(List.of(first, second));
    doAnswer(invocation -> {
      UUID planId = invocation.getArgument(0);
      if (first.equals(planId)) throw new IllegalStateException("boom");
      return null;
    }).when(service).executeDuePlan(any(UUID.class), any(Instant.class));

    new ScheduledAssignmentScheduler(service).tick();

    verify(service).executeDuePlan(org.mockito.ArgumentMatchers.eq(first), any(Instant.class));
    verify(service).executeDuePlan(org.mockito.ArgumentMatchers.eq(second), any(Instant.class));
  }
}
