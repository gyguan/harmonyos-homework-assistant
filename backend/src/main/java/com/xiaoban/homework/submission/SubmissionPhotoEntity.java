package com.xiaoban.homework.submission;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.util.UUID;

@Entity(name = "submission_photo")
public class SubmissionPhotoEntity {
  @Id public UUID id;
  public UUID submissionId;
  public UUID familyId;
  public String assignmentId;
  public String storagePath;
  public String originalName;
  public String contentType;
  public long sizeBytes;
  protected SubmissionPhotoEntity() {}
}
