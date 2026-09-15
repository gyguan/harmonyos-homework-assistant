package com.xiaoban.homework.tutor;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "tutor_session")
public class TutorSessionEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String assignmentId;
  public Instant createdAt;
  public Instant updatedAt;

  protected TutorSessionEntity() {}
}
