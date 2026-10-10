package com.xiaoban.homework.toeic;

import jakarta.validation.constraints.Min;

public final class ToeicVocabularyRecallDtos {
  private ToeicVocabularyRecallDtos() {}

  public record UpsertRequest(
      boolean remembered,
      @Min(0) int streak,
      @Min(0) int totalReviews,
      @Min(1) long nextDueAtEpochMs,
      @Min(1) long lastReviewedAtEpochMs) {}

  public record Response(
      String vocabularyId,
      boolean remembered,
      int streak,
      int totalReviews,
      long nextDueAtEpochMs,
      long lastReviewedAtEpochMs,
      long updatedAtEpochMs) {

    static Response from(ToeicVocabularyRecallEntity entity) {
      return new Response(
          entity.vocabularyId,
          entity.remembered,
          entity.streak,
          entity.totalReviews,
          entity.nextDueAt.toEpochMilli(),
          entity.lastReviewedAt.toEpochMilli(),
          entity.updatedAt.toEpochMilli());
    }
  }
}
