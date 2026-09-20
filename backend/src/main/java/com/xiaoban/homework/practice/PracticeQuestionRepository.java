package com.xiaoban.homework.practice;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticeQuestionRepository extends JpaRepository<PracticeQuestionEntity, String> {
  List<PracticeQuestionEntity> findByPaperKeyOrderByOrderNo(String paperKey);
  long countByPaperKey(String paperKey);
}
