package com.xiaoban.homework.scheduledassignment;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "scheduled_assignment_run")
public class ScheduledAssignmentRunEntity {
  @Id public UUID id;
  public UUID planId;
  public Instant scheduledFireAt;
  public String triggerSource;
  public String status;
  public String assignmentId;
  public String skipReason;
  public String errorMessage;
  public int retryCount;
  public Instant createdAt;
  public Instant finishedAt;

  protected ScheduledAssignmentRunEntity() {}
}
