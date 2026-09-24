package com.xiaoban.homework.voicematerial;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "voice_material_task_link")
public class VoiceMaterialTaskLinkEntity {
  @Id public String id;
  public UUID familyId;
  public String studentId;
  public UUID packageId;
  public String assignmentId;
  public String assignmentTitle;
  public String createMode;
  public String requestId;
  public Instant createdAt;

  protected VoiceMaterialTaskLinkEntity() {}
}
