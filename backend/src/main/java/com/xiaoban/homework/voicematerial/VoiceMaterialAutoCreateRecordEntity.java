package com.xiaoban.homework.voicematerial;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "voice_material_auto_create_record")
public class VoiceMaterialAutoCreateRecordEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public LocalDate businessDate;
  public UUID packageId;
  public String assignmentId;
  public Instant createdAt;

  protected VoiceMaterialAutoCreateRecordEntity() {}
}
