package com.xiaoban.homework.practice;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "practice_question")
public class PracticeQuestionEntity {
  @Id public String id;
  public String paperKey;
  public int orderNo;
  public String questionType;
  public String stem;
  public String optionsJson;
  public String answerSpec;
  public String explanation;
  public String hintsJson;
  public String tagsJson;

  protected PracticeQuestionEntity() {}
}
