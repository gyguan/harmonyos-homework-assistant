package com.xiaoban.homework.coverage;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity(name = "daily_homework_coverage")
public class DailyHomeworkCoverageEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public LocalDate taskDate;
  public UUID accountId;
  public String parentIdentity;
  public String subjectCode;
  public Instant createdAt;
  public Instant updatedAt;

  protected DailyHomeworkCoverageEntity() {}
}
