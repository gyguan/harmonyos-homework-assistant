package com.xiaoban.homework.voicematerial;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "voice_material_batch")
public class VoiceMaterialBatchEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public int directoryCount;
  public int readyCount;
  public int invalidCount;
  public Instant createdAt;
  public Instant updatedAt;

  protected VoiceMaterialBatchEntity() {}
}
