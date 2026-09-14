package com.xiaoban.homework.submission;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "submission")
public class SubmissionEntity {
  @Id public UUID id;
  public UUID familyId;
  public String assignmentId;
  public Instant submittedAt;
  public Instant createdAt;
  protected SubmissionEntity() {}
}
