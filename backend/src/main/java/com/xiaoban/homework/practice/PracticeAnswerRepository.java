package com.xiaoban.homework.practice;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticeAnswerRepository extends JpaRepository<PracticeAnswerEntity, UUID> {
  Optional<PracticeAnswerEntity> findByAttemptIdAndQuestionId(UUID attemptId, String questionId);
  List<PracticeAnswerEntity> findByAttemptId(UUID attemptId);
}
