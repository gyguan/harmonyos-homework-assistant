package com.xiaoban.homework.practice;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "practice_attempt")
public class PracticeAttemptEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String paperId;
  public int paperVersion;
  public int attemptNo;
  public String mode;
  public String status;
  public UUID sourceAttemptId;
  public String questionIdsJson;
  public Instant startedAt;
  public Instant submittedAt;
  public long elapsedSeconds;
  public int score;
  public int maxScore;
  public int correctCount;
  public int wrongCount;

  protected PracticeAttemptEntity() {}
}
