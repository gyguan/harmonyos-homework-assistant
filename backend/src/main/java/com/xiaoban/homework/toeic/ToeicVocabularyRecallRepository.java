package com.xiaoban.homework.toeic;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ToeicVocabularyRecallRepository extends JpaRepository<ToeicVocabularyRecallEntity, UUID> {
  Optional<ToeicVocabularyRecallEntity> findByFamilyIdAndStudentIdAndVocabularyId(
      UUID familyId, String studentId, String vocabularyId);
  List<ToeicVocabularyRecallEntity> findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(
      UUID familyId, String studentId);
}
