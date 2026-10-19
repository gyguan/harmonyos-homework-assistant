package com.xiaoban.homework.organizer;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;

@Entity(name = "homework_feedback_type")
public class HomeworkFeedbackTypeEntity {
  @Id public String code;
  public String label;
  public String description;
  public boolean requiresComment;
  public boolean enabled;
  public int displayOrder;
  public Instant createdAt;
  public Instant updatedAt;

  protected HomeworkFeedbackTypeEntity() {}
}
