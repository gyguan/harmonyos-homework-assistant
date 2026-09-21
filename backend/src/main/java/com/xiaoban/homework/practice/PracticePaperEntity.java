package com.xiaoban.homework.practice;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "practice_paper")
public class PracticePaperEntity {
  @Id public String paperKey;
  public String paperId;
  public int version;
  public String grade;
  public String subject;
  public String semester;
  public String track;
  public String title;
  public String description;
  public String difficulty;
  public int questionCount;
  public int estimatedMinutes;
  public String tagsJson;
  public String sourceType;
  public String status;
  public Instant createdAt;
  public Instant updatedAt;

  protected PracticePaperEntity() {}
}
