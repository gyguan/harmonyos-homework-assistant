package com.xiaoban.homework.organizer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "homework_organizer_feedback")
public class HomeworkOrganizerFeedbackEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String clientRequestId;
  public String candidateId;
  public String batchId;
  public String teacherName;
  public String subject;
  public String feedbackTypeCode;
  public String sourceLabel;
  @Column(length = 500) public String sourceExcerpt;
  @Column(length = 400) public String originalTitle;
  @Column(length = 400) public String currentTitle;
  @Column(length = 1200) public String details;
  public String processingStatus;
  public Instant createdAt;

  protected HomeworkOrganizerFeedbackEntity() {}
}
