package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeworkReviewOutboxEnqueuer {
  private final HomeworkReviewOutboxRepository outbox;
  private final HomeworkOrganizerAiSnapshotRepository snapshots;

  public HomeworkReviewOutboxEnqueuer(HomeworkReviewOutboxRepository outbox,
      HomeworkOrganizerAiSnapshotRepository snapshots) {
    this.outbox = outbox;
    this.snapshots = snapshots;
  }

  /** Mandatory publish transaction: cannot commit assignments without the pending review. */
  @Transactional(propagation = Propagation.MANDATORY)
  public void enqueue(UUID familyId, String studentId, String batchId, List<String> ids) {
    if (batchId == null || batchId.isBlank()) return; // legacy request
    if (!batchId.matches("[A-Za-z0-9_-]{1,140}")) {
      throw new ApiExceptions.BadRequest("导入批次不合法");
    }
    // Non-AI manual work needs no reconciliation job.
    if (snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        familyId, studentId, batchId).isEmpty()) return;
    if (ids.isEmpty() || ids.size() > 50 || ids.stream().anyMatch(
        id -> id == null || !id.matches("[A-Za-z0-9_-]{1,180}"))) {
      throw new ApiExceptions.BadRequest("已发布作业标识不合法");
    }
    String encoded = String.join("\n", ids);
    var existing = outbox.findByFamilyIdAndStudentIdAndBatchId(familyId, studentId, batchId);
    if (existing.isPresent()) {
      if (!existing.get().candidateIds.equals(encoded)) {
        throw new ApiExceptions.BadRequest("该导入批次已有不同的发布结果");
      }
      return;
    }
    var row = new HomeworkReviewOutboxEntity();
    row.id = UUID.randomUUID();
    row.familyId = familyId;
    row.studentId = studentId;
    row.batchId = batchId;
    row.candidateIds = encoded;
    row.status = "PENDING";
    row.attempts = 0;
    row.lastError = "";
    row.createdAt = Instant.now();
    row.updatedAt = row.createdAt;
    row.nextAttemptAt = row.createdAt;
    outbox.save(row);
  }
}
