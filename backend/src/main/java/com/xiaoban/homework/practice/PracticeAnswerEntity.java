package com.xiaoban.homework.practice;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "practice_answer")
public class PracticeAnswerEntity {
  @Id public UUID id;
  public UUID familyId;
  public UUID attemptId;
  public String questionId;
  public String answerValue;
  public Boolean isCorrect;
  public int score;
  public Instant answeredAt;

  protected PracticeAnswerEntity() {}
}
