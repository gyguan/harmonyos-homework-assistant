package com.xiaoban.homework.organizer;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeworkFeedbackTypeRepository extends JpaRepository<HomeworkFeedbackTypeEntity, String> {
  List<HomeworkFeedbackTypeEntity> findByEnabledTrueOrderByDisplayOrderAsc();
}
