package com.xiaoban.homework.assignment;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "assignment_resource")
public class AssignmentResourceEntity {
  @Id public UUID id;
  public UUID familyId;
  public String assignmentId;
  public String resourceType;
  public String storagePath;
  public UUID assetId;
  public String originalName;
  public String contentType;
  public long sizeBytes;
  public int sortOrder;
  public long durationMs;
  public Instant createdAt;

  protected AssignmentResourceEntity() {}
}
