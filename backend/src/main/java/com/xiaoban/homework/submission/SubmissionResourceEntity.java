package com.xiaoban.homework.submission;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "submission_resource")
public class SubmissionResourceEntity {
  @Id public UUID id;
  public UUID submissionId;
  public UUID familyId;
  public String assignmentId;
  public String resourceType;
  public String storagePath;
  public String originalName;
  public String contentType;
  public long sizeBytes;
  public long durationMs;
  public int sortOrder;
  public Instant createdAt;
  protected SubmissionResourceEntity() {}
}
