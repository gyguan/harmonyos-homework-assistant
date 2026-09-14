package com.xiaoban.homework.auth;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class AuthTokenService {
  private record Session(UUID familyId, Instant expiresAt) {}
  private final Map<String, Session> sessions = new ConcurrentHashMap<>();
  private final Duration ttl;

  public AuthTokenService(@Value("${app.auth.token-ttl-hours:24}") long ttlHours) {
    this.ttl = Duration.ofHours(ttlHours);
  }

  public String issue(UUID familyId) {
    String token = UUID.randomUUID().toString().replace("-", "") + UUID.randomUUID().toString().replace("-", "");
    sessions.put(token, new Session(familyId, Instant.now().plus(ttl)));
    return token;
  }

  public UUID requireFamily(String token) {
    Session session = token == null ? null : sessions.get(token);
    if (session == null || session.expiresAt().isBefore(Instant.now())) {
      if (token != null) sessions.remove(token);
      throw new ApiExceptions.Unauthorized("登录状态已失效，请重新登录");
    }
    return session.familyId();
  }
}
