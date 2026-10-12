package com.xiaoban.homework.mediasync;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "assignment_media_sync")
public class AssignmentMediaSyncEntity {
  @Id public UUID id;
  public UUID familyId;
  public String assignmentId;
  public String mediaFingerprint;
  public String status;
  public int syncVersion;
  public UUID audioResourceId;
  public long audioDurationMs;
  public double confidence;
  public String timelineJson;
  public String analysisModel;
  public String transcriptionModel;
  public int attemptCount;
  public Instant nextRetryAt;
  public String errorCode;
  public String errorMessage;
  public Instant startedAt;
  public Instant finishedAt;
  public Instant createdAt;
  public Instant updatedAt;

  protected AssignmentMediaSyncEntity() {}
}
