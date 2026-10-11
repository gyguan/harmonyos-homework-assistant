package com.xiaoban.homework.toeic;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ToeicVocabularyRecallService {
  private static final Logger log = LoggerFactory.getLogger(ToeicVocabularyRecallService.class);
  private final ToeicVocabularyRecallRepository repository;

  public ToeicVocabularyRecallService(ToeicVocabularyRecallRepository repository) {
    this.repository = repository;
  }

  @Transactional(readOnly = true)
  public List<ToeicVocabularyRecallDtos.Response> list(UUID accountId) {
    return repository.findByAccountIdOrderByUpdatedAtDesc(accountId)
        .stream().map(ToeicVocabularyRecallDtos.Response::from).toList();
  }

  @Transactional
  public ToeicVocabularyRecallDtos.Response upsert(
      UUID accountId,
      String vocabularyId,
      ToeicVocabularyRecallDtos.UpsertRequest input) {
    String normalizedId = vocabularyId == null ? "" : vocabularyId.trim();
    if (normalizedId.isEmpty() || normalizedId.length() > 120) {
      throw new ApiExceptions.BadRequest("TOEIC 单词 ID 无效");
    }
    if (input.totalReviews() < input.streak()) {
      throw new ApiExceptions.BadRequest("TOEIC 单词复习次数无效");
    }
    if (input.nextDueAtEpochMs() < input.lastReviewedAtEpochMs()) {
      throw new ApiExceptions.BadRequest("TOEIC 单词下次复习时间无效");
    }

    Instant incomingReviewedAt = Instant.ofEpochMilli(input.lastReviewedAtEpochMs());
    ToeicVocabularyRecallEntity entity = repository
        .findByAccountIdAndVocabularyId(accountId, normalizedId)
        .orElseGet(ToeicVocabularyRecallEntity::new);

    if (entity.id != null && !incomingReviewedAt.isAfter(entity.lastReviewedAt)) {
      return ToeicVocabularyRecallDtos.Response.from(entity);
    }

    Instant now = Instant.now();
    if (entity.id == null) {
      entity.id = UUID.randomUUID();
      entity.accountId = accountId;
      entity.vocabularyId = normalizedId;
      entity.createdAt = now;
    }
    entity.remembered = input.remembered();
    entity.streak = input.streak();
    entity.totalReviews = input.totalReviews();
    entity.nextDueAt = Instant.ofEpochMilli(input.nextDueAtEpochMs());
    entity.lastReviewedAt = incomingReviewedAt;
    entity.updatedAt = now;
    repository.save(entity);
    log.info(
        "toeic_vocabulary recall_saved accountId={} vocabularyId={} remembered={} streak={} totalReviews={}",
        accountId, normalizedId, entity.remembered, entity.streak, entity.totalReviews);
    return ToeicVocabularyRecallDtos.Response.from(entity);
  }
}
