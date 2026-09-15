package com.xiaoban.homework.tutor;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TutorMessageRepository extends JpaRepository<TutorMessageEntity, UUID> {
  List<TutorMessageEntity> findBySessionIdOrderByCreatedAt(UUID sessionId);
}
