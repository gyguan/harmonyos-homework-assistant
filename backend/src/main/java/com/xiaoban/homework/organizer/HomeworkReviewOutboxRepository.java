package com.xiaoban.homework.organizer;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface HomeworkReviewOutboxRepository extends JpaRepository<HomeworkReviewOutboxEntity,UUID> {
  Optional<HomeworkReviewOutboxEntity> findByFamilyIdAndStudentIdAndBatchId(
      UUID familyId, String studentId, String batchId);

  List<HomeworkReviewOutboxEntity> findTop20ByStatusAndNextAttemptAtLessThanEqualOrderByNextAttemptAtAsc(
      String status, Instant due);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select e from HomeworkReviewOutboxEntity e where e.id = :id")
  Optional<HomeworkReviewOutboxEntity> lockById(@Param("id") UUID id);
}
