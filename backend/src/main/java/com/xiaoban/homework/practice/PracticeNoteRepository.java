package com.xiaoban.homework.practice;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticeNoteRepository extends JpaRepository<PracticeNoteEntity, UUID> {
  Optional<PracticeNoteEntity> findByAttemptIdAndQuestionId(UUID attemptId, String questionId);
  List<PracticeNoteEntity> findByAttemptId(UUID attemptId);
  long countByAttemptId(UUID attemptId);
}
