package com.xiaoban.homework.practice;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "practice_generation")
public class PracticeGenerationEntity {
  @Id public UUID id;
  public UUID familyId;
  public String referenceStudentId;
  public String referenceTextbookSummary;
  public String subject;
  public String semester;
  public String track;
  public String difficulty;
  public int questionCount;
  public String requirement;
  public String status;
  public String generatedJson;
  public String paperId;
  public Integer paperVersion;
  public String model;
  public String errorMessage;
  public Instant createdAt;
  public Instant updatedAt;

  protected PracticeGenerationEntity() {}
}
