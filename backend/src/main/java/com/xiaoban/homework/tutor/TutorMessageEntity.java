package com.xiaoban.homework.tutor;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "tutor_message")
public class TutorMessageEntity {
  @Id public UUID id;
  public UUID sessionId;
  public String role;
  public String content;
  public Instant createdAt;

  protected TutorMessageEntity() {}
}
