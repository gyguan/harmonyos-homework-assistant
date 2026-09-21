package com.xiaoban.homework.practice;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "practice_note")
public class PracticeNoteEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public UUID attemptId;
  public String questionId;
  public String content;
  public Instant createdAt;
  public Instant updatedAt;

  protected PracticeNoteEntity() {}
}
