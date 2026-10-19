package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

class HomeworkReviewOutboxTest {
  private final UUID family = UUID.randomUUID();
  private final String child = "student-1", batch = "text-100";

  private HomeworkOrganizerAiSnapshotEntity original() {
    var e = new HomeworkOrganizerAiSnapshotEntity();
    e.candidateId = "ai-text-100-1";
    return e;
  }

  @Test
  void atomicEnqueuerRequiresPublishTransactionAndStoresOnlyIdentifiers() throws Exception {
    var method = HomeworkReviewOutboxEnqueuer.class.getMethod(
        "enqueue", UUID.class, String.class, String.class, List.class);
    assertEquals(Propagation.MANDATORY, method.getAnnotation(Transactional.class).propagation());
    var repo = mock(HomeworkReviewOutboxRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, child, batch)).thenReturn(List.of(original()));
    var service = new HomeworkReviewOutboxEnqueuer(repo, snapshots);
    service.enqueue(family, child, batch, List.of("ai-text-100-1", "manual-text-100-2"));
    var captor = org.mockito.ArgumentCaptor.forClass(HomeworkReviewOutboxEntity.class);
    verify(repo).save(captor.capture());
    var saved = captor.getValue();
    assertEquals(family, saved.familyId);
    assertEquals(child, saved.studentId);
    assertEquals(batch, saved.batchId);
    assertEquals("ai-text-100-1\nmanual-text-100-2", saved.candidateIds);
    assertEquals("PENDING", saved.status);
    assertEquals(0, saved.attempts);
    assertNotNull(saved.nextAttemptAt);
  }

  @Test
  void repeatedPublishCannotOverwriteOutboxAndRejectsForeignBatchCandidate() {
    var repo = mock(HomeworkReviewOutboxRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, child, batch)).thenReturn(List.of(original()));
    var service = new HomeworkReviewOutboxEnqueuer(repo, snapshots);
    var old = new HomeworkReviewOutboxEntity();
    old.candidateIds = "ai-text-100-1";
    when(repo.findByFamilyIdAndStudentIdAndBatchId(family, child, batch))
        .thenReturn(Optional.of(old));
    service.enqueue(family, child, batch, List.of("ai-text-100-1"));
    verify(repo, never()).save(any());
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.enqueue(family, child, batch, List.of("ai-another-1")));
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.enqueue(family, child, batch, List.of("manual-another-1")));
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.enqueue(family, child, batch, List.of("ai-text-100-1", "ai-text-100-1")));
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.enqueue(family, child, batch, List.of("ai-text-100-1", "manual-text-100-2")));
    verify(repo, never()).save(any());
  }

  @Test
  void olderOrNonAiBatchDoesNotCreateQueueJobs() {
    var repo = mock(HomeworkReviewOutboxRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var service = new HomeworkReviewOutboxEnqueuer(repo, snapshots);
    service.enqueue(family, child, "", List.of("manual-1"));
    service.enqueue(family, child, "legacy-100", List.of("manual-1"));
    verify(repo, never()).save(any());
  }

  @Test
  void processorCompletesWhenReconciliationSucceedsAndSkipsCompletedRows() {
    var repo = mock(HomeworkReviewOutboxRepository.class);
    var reviews = mock(HomeworkOrganizerReviewDifferenceService.class);
    var e = new HomeworkReviewOutboxEntity();
    e.id = UUID.randomUUID();
    e.familyId = family;
    e.studentId = child;
    e.batchId = batch;
    e.candidateIds = "ai-text-100-1\nmanual-text-100-2";
    e.status = "PENDING";
    e.nextAttemptAt = Instant.now().minusSeconds(10);
    when(repo.lockById(e.id)).thenReturn(Optional.of(e));
    var processor = new HomeworkReviewOutboxProcessor(repo, reviews);
    processor.process(e.id);
    assertEquals("COMPLETED", e.status);
    var captor = org.mockito.ArgumentCaptor.forClass(
        HomeworkOrganizerReviewDifferenceService.Finalize.class);
    verify(reviews).finalizePublished(eq(family), eq(child), captor.capture());
    assertEquals(List.of("ai-text-100-1", "manual-text-100-2"), captor.getValue().publishedCandidateIds());
    processor.process(e.id);
    verify(reviews, times(1)).finalizePublished(any(), any(), any());
  }

  @Test
  void failedReviewRetriesInSeparateTransactionThenStopsAfterEight() throws Exception {
    var marker = HomeworkReviewOutboxProcessor.class.getMethod(
        "markFailedAttempt", UUID.class, RuntimeException.class);
    assertEquals(Propagation.REQUIRES_NEW,
        marker.getAnnotation(Transactional.class).propagation());
    var repo = mock(HomeworkReviewOutboxRepository.class);
    var reviews = mock(HomeworkOrganizerReviewDifferenceService.class);
    var e = new HomeworkReviewOutboxEntity();
    e.id = UUID.randomUUID();
    e.familyId = family;
    e.studentId = child;
    e.batchId = batch;
    e.candidateIds = "ai-text-100-1";
    e.status = "PENDING";
    e.nextAttemptAt = Instant.now().minusSeconds(10);
    when(repo.lockById(e.id)).thenReturn(Optional.of(e));
    doThrow(new IllegalStateException("database unavailable")).when(reviews)
        .finalizePublished(any(), any(), any());
    var processor = new HomeworkReviewOutboxProcessor(repo, reviews);
    assertThrows(IllegalStateException.class, () -> processor.process(e.id));
    processor.markFailedAttempt(e.id, new IllegalStateException("database unavailable"));
    assertEquals("PENDING", e.status);
    assertEquals(1, e.attempts);
    assertTrue(e.nextAttemptAt.isAfter(Instant.now()));
    assertEquals("IllegalStateException", e.lastError);
    for (int i = 1; i < 8; i++) processor.markFailedAttempt(e.id, new IllegalStateException());
    assertEquals("FAILED", e.status);
    assertEquals(8, e.attempts);
    processor.markFailedAttempt(e.id, new IllegalStateException());
    assertEquals(8, e.attempts);
  }
}
