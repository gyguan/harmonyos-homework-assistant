package com.xiaoban.homework.voicematerial;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "voice_material_file")
public class VoiceMaterialFileEntity {
  @Id public UUID id;
  public UUID packageId;
  public UUID familyId;
  public UUID assetId;
  public String resourceType;
  public String relativeName;
  public int sortOrder;
  public Instant createdAt;

  protected VoiceMaterialFileEntity() {}
}
