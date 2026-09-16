package com.xiaoban.homework.assignment;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "assignment")
public class AssignmentEntity {
  @Id public String id;
  public UUID familyId;
  public String studentId;
  public String assignmentType;
  public String subjectCode;
  public String subject;
  public String title;
  public String instruction;
  public String textbookRef;
  public Instant dueAt;
  public String dueTimezone;
  public String dueText;
  public String status;
  public String sourceLabel;
  public String sourceExcerpt;
  public int expectedMinutes;
  public long startedAtEpochMs;
  public long finishedAtEpochMs;
  public long elapsedSeconds;
  public String reviewNote;
  @Version public long version;
  public Instant createdAt;
  public Instant updatedAt;

  protected AssignmentEntity() {}
}
