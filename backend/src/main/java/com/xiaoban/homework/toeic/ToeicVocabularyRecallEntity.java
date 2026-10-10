package com.xiaoban.homework.toeic;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "toeic_vocabulary_recall")
public class ToeicVocabularyRecallEntity {
  @Id public UUID id;
  public UUID familyId;
  public String studentId;
  public String vocabularyId;
  public boolean remembered;
  public int streak;
  public int totalReviews;
  public Instant nextDueAt;
  public Instant lastReviewedAt;
  public Instant createdAt;
  public Instant updatedAt;

  protected ToeicVocabularyRecallEntity() {}
}
