package com.xiaoban.homework.voicematerial;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "voice_material_package")
public class VoiceMaterialPackageEntity {
  @Id public UUID id;
  public UUID batchId;
  public UUID familyId;
  public String studentId;
  public String directoryName;
  public String subjectCode;
  public String title;
  public int expectedMinutes;
  public Instant dueAt;
  public String assignmentType;
  public String status;
  public String packageFingerprint;
  public String consumedAssignmentId;
  public Instant consumedAt;
  public String errorMessage;
  public Instant createdAt;
  public Instant updatedAt;

  protected VoiceMaterialPackageEntity() {}
}
