package com.xiaoban.homework.student;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "student")
public class StudentEntity {
  @Id public String id;
  public UUID familyId;
  public String name;
  public String grade;
  public String className;
  public String semester;
  public String textbookSummary;
  public String chineseTextbook;
  public String mathTextbook;
  public String englishTextbook;
  public String otherTextbooks;
  public Instant createdAt;
  public Instant updatedAt;

  protected StudentEntity() {}
}
