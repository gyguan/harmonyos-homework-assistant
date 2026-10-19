package com.xiaoban.homework.organizer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "homework_organizer_ai_snapshot")
public class HomeworkOrganizerAiSnapshotEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String batchId;
  public String candidateId;
  public String teacherName;
  public String subject;
  @Column(length = 400) public String title;
  @Column(length = 1500) public String instruction;
  public String textbookRef;
  public String taskDate;
  public int expectedMinutes;
  @Column(length = 500) public String sourceExcerpt;
  public Instant createdAt;
  protected HomeworkOrganizerAiSnapshotEntity() {}
}
