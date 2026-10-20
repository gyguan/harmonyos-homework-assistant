package com.xiaoban.homework.organizer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name = "homework_source_evidence")
public class HomeworkSourceEvidenceEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String batchId;
  @Column(columnDefinition = "text") public String evidenceJson;
  public Instant createdAt;
  protected HomeworkSourceEvidenceEntity() {}
}
