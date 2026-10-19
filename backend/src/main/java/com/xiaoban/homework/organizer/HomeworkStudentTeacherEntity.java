package com.xiaoban.homework.organizer;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "homework_student_teacher")
public class HomeworkStudentTeacherEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String teacherName;
  public String subject;
  public boolean enabled = true;
  public Instant createdAt;
  public Instant updatedAt;
  protected HomeworkStudentTeacherEntity() {}
}
