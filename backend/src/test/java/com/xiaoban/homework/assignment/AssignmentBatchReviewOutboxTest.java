package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import com.xiaoban.homework.organizer.HomeworkReviewOutboxEnqueuer;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;

class AssignmentBatchReviewOutboxTest {
  private AssignmentDtos.BatchPublishItem task(String id) {
    var dto = new AssignmentDtos.Create("a-published-" + id, "语文", "读课文",
        "读课文", "", "2026-10-19", "SCHOOL", "CHINESE", "NORMAL", "NOT_STARTED",
        "来源", "国13", 20, 0L, 0L, 0L, "");
    return new AssignmentDtos.BatchPublishItem(id, dto);
  }

  @Test
  void sameTransactionalPublishEnqueuesReviewBeforeReturningSuccess() throws Exception {
    assertNotNull(AssignmentBatchPublishService.class
        .getMethod("publish", UUID.class, String.class, AssignmentDtos.BatchPublishRequest.class)
        .getAnnotation(Transactional.class));
    var assignments = mock(AssignmentService.class);
    var outbox = mock(HomeworkReviewOutboxEnqueuer.class);
    var service = new AssignmentBatchPublishService(assignments, outbox);
    UUID family = UUID.randomUUID();
    var request = new AssignmentDtos.BatchPublishRequest(
        List.of(task("ai-text-100-1"), task("manual-text-100-2")), "text-100");
    var response = service.publish(family, "child-1", request);
    assertTrue(response.atomic());
    assertEquals(2, response.publishedCount());
    verify(assignments, times(2)).create(eq(family), eq("child-1"), any());
    verify(outbox).enqueue(family, "child-1", "text-100",
        List.of("ai-text-100-1", "manual-text-100-2"));
  }

  @Test
  void failedOutboxEnqueueAbortsPublishInsteadOfReturningFalseSuccess() {
    var assignments = mock(AssignmentService.class);
    var outbox = mock(HomeworkReviewOutboxEnqueuer.class);
    var service = new AssignmentBatchPublishService(assignments, outbox);
    UUID family = UUID.randomUUID();
    doThrow(new IllegalStateException("transaction rollback")).when(outbox)
        .enqueue(any(), any(), any(), any());
    assertThrows(IllegalStateException.class, () -> service.publish(family, "child-1",
        new AssignmentDtos.BatchPublishRequest(List.of(task("ai-text-100-1")), "text-100")));
  }

  @Test
  void legacyBatchRequestWorksWithoutReviewJob() {
    var assignments = mock(AssignmentService.class);
    var outbox = mock(HomeworkReviewOutboxEnqueuer.class);
    var service = new AssignmentBatchPublishService(assignments, outbox);
    var response = service.publish(UUID.randomUUID(), "child-1",
        new AssignmentDtos.BatchPublishRequest(List.of(task("manual-1"))));
    assertEquals(1, response.publishedCount());
    verifyNoInteractions(outbox);
  }
}
