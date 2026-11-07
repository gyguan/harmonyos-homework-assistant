package com.xiaoban.homework.organizer;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.time.Instant;
import java.util.UUID;

@Entity(name = "homework_organizer_rule")
public class HomeworkOrganizerRuleEntity {
  @Id @Column(length = 80) public String code;
  @Column(length = 16) public String ruleType;
  @Column(length = 16) public String scope;
  public UUID familyId;
  @Column(length = 80) public String studentId;
  @Column(length = 80) public String teacherName;
  @Column(length = 20) public String subject;
  @Column(length = 120) public String triggerText;
  @Column(length = 1200) public String meaning;
  @Column(length = 200) public String shortTitle;
  @Column(columnDefinition = "text") public String promptText;
  @Column(length = 32) public String templateKey;
  public int priority;
  public boolean enabled;
  public int version;
  @Column(length = 24) public String origin;
  public Instant createdAt;
  public Instant updatedAt;
  protected HomeworkOrganizerRuleEntity() {}
}
