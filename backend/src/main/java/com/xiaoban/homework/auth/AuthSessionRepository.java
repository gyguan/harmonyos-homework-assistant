package com.xiaoban.homework.auth;

import java.time.Instant;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuthSessionRepository extends JpaRepository<AuthSessionEntity, String> {
  long deleteByExpiresAtBefore(Instant cutoff);
}
