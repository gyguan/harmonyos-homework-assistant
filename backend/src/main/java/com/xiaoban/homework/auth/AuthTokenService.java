package com.xiaoban.homework.auth;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthTokenService {
  public record SessionInfo(UUID accountId, UUID familyId) {}

  private final AuthSessionRepository sessions;
  private final Duration ttl;

  public AuthTokenService(AuthSessionRepository sessions, @Value("${app.auth.token-ttl-hours:168}") long ttlHours) {
    this.sessions = sessions;
    this.ttl = Duration.ofHours(ttlHours);
  }

  @Transactional
  public String issue(UUID accountId, UUID familyId) {
    String token = UUID.randomUUID().toString().replace("-", "") + UUID.randomUUID().toString().replace("-", "");
    AuthSessionEntity session = new AuthSessionEntity();
    session.token = token;
    session.accountId = accountId;
    session.familyId = familyId;
    session.createdAt = Instant.now();
    session.expiresAt = session.createdAt.plus(ttl);
    sessions.save(session);
    return token;
  }

  @Transactional
  public SessionInfo requireSession(String token) {
    AuthSessionEntity session = token == null ? null : sessions.findById(token).orElse(null);
    if (session == null || session.expiresAt.isBefore(Instant.now())) {
      if (session != null) sessions.delete(session);
      throw new ApiExceptions.Unauthorized("登录状态已失效，请重新登录");
    }
    return new SessionInfo(session.accountId, session.familyId);
  }

  public UUID requireFamily(String token) {
    return requireSession(token).familyId();
  }

  @Transactional
  public void revoke(String token) {
    if (token != null && !token.isBlank()) sessions.deleteById(token);
  }
}
