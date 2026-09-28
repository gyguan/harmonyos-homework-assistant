package com.xiaoban.homework.scheduledassignment;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.time.LocalTime;
import java.util.UUID;

@Entity(name = "scheduled_assignment_template")
public class ScheduledAssignmentTemplateEntity {
  @Id public UUID planId;
  public String assignmentType;
  public String subject;
  public String subjectCode;
  public String title;
  public String instruction;
  public int expectedMinutes;
  public String duePolicy;
  public LocalTime dueTime;
  public Integer dueOffsetMinutes;
  public Instant createdAt;
  public Instant updatedAt;

  protected ScheduledAssignmentTemplateEntity() {}
}
