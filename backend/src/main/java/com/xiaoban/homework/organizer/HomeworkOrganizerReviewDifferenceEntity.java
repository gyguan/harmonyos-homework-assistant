package com.xiaoban.homework.organizer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "homework_organizer_review_difference")
public class HomeworkOrganizerReviewDifferenceEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String batchId;
  public String candidateId;
  public String teacherName;
  public String changeType;
  public String fieldName;
  @Column(length = 1500) public String beforeValue;
  @Column(length = 1500) public String afterValue;
  @Column(length = 500) public String sourceExcerpt;
  public Instant createdAt;
  protected HomeworkOrganizerReviewDifferenceEntity() {}
}
