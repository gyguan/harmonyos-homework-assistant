package com.xiaoban.homework.practice;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "practice_paper_audience")
public class PracticePaperAudienceEntity {
  @Id public UUID id;
  public String paperKey;
  public UUID familyId;
  public String studentId;
  public Instant assignedAt;

  protected PracticePaperAudienceEntity() {}
}
