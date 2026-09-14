package com.xiaoban.homework.auth;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "auth_session")
public class AuthSessionEntity {
  @Id public String token;
  public UUID accountId;
  public UUID familyId;
  public Instant expiresAt;
  public Instant createdAt;

  protected AuthSessionEntity() {}
}
