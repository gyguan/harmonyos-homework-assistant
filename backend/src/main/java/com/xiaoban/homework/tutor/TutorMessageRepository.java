package com.xiaoban.homework.tutor;

import java.util.List;
import java.time.Instant;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TutorMessageRepository extends JpaRepository<TutorMessageEntity, UUID> {
  List<TutorMessageEntity> findBySessionIdOrderByCreatedAt(UUID sessionId);
  List<TutorMessageEntity> findBySessionIdOrderByCreatedAtDesc(UUID sessionId, Pageable pageable);
  List<TutorMessageEntity> findBySessionIdAndCreatedAtBeforeOrderByCreatedAtDesc(
      UUID sessionId, Instant before, Pageable pageable);
}
