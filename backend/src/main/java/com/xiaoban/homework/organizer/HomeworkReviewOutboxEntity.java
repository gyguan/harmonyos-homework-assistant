package com.xiaoban.homework.organizer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "homework_review_outbox")
public class HomeworkReviewOutboxEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String batchId;
  @Column(length = 10000) public String candidateIds;
  public String status;
  public int attempts;
  public Instant nextAttemptAt;
  public String lastError;
  public Instant createdAt;
  public Instant updatedAt;
  protected HomeworkReviewOutboxEntity() {}
}
