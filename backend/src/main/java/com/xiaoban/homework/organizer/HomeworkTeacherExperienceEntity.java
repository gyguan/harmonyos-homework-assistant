package com.xiaoban.homework.organizer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "homework_teacher_experience")
public class HomeworkTeacherExperienceEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String teacherName;
  public String subject;
  public String cue;
  @Column(length = 600) public String interpretation;
  @Column(length = 400) public String exampleSource;
  @Column(length = 400) public String exampleResult;
  public String origin;
  public boolean active = true;
  public UUID sourceFeedbackId;
  public Instant createdAt;
  public Instant updatedAt;

  protected HomeworkTeacherExperienceEntity() {}
}
