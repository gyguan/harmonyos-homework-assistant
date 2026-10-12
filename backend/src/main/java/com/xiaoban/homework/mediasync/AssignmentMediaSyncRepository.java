package com.xiaoban.homework.mediasync;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AssignmentMediaSyncRepository extends JpaRepository<AssignmentMediaSyncEntity, UUID> {
  Optional<AssignmentMediaSyncEntity> findByFamilyIdAndAssignmentId(UUID familyId, String assignmentId);
  Optional<AssignmentMediaSyncEntity> findFirstByFamilyIdAndMediaFingerprintAndStatusOrderByFinishedAtDesc(
      UUID familyId, String mediaFingerprint, String status);
  List<AssignmentMediaSyncEntity> findTop2ByStatusAndNextRetryAtLessThanEqualOrderByCreatedAtAsc(
      String status, Instant nextRetryAt);
  List<AssignmentMediaSyncEntity> findTop10ByStatusAndStartedAtBeforeOrderByStartedAtAsc(
      String status, Instant startedAt);
}
