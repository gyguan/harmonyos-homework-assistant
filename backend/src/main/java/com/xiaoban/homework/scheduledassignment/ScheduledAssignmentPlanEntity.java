package com.xiaoban.homework.scheduledassignment;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Version;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

@Entity(name = "scheduled_assignment_plan")
public class ScheduledAssignmentPlanEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String planType;
  public String name;
  public String scheduleType;
  public LocalTime scheduleTime;
  public String weekdays;
  public LocalDate startDate;
  public LocalDate endDate;
  public String timezone;
  public String status;
  public Instant nextFireAt;
  public Instant lastFireAt;
  public Instant createdAt;
  public Instant updatedAt;
  @Version public long version;

  protected ScheduledAssignmentPlanEntity() {}
}
