package com.xiaoban.homework.auth;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "account")
public class AccountEntity {
  @Id public UUID id;
  public UUID familyId;
  public String loginName;
  public String passwordHash;
  public String displayName;
  public Instant createdAt;
  public Instant updatedAt;

  protected AccountEntity() {}
  public AccountEntity(UUID id, UUID familyId, String loginName, String passwordHash, String displayName, Instant now) {
    this.id = id; this.familyId = familyId; this.loginName = loginName; this.passwordHash = passwordHash;
    this.displayName = displayName; this.createdAt = now; this.updatedAt = now;
  }
}
