package com.xiaoban.homework.family;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "family")
public class FamilyEntity {
  @Id public UUID id;
  public String name;
  public Instant createdAt;
  public Instant updatedAt;

  protected FamilyEntity() {}
  public FamilyEntity(UUID id, String name, Instant now) {
    this.id = id; this.name = name; this.createdAt = now; this.updatedAt = now;
  }
}
