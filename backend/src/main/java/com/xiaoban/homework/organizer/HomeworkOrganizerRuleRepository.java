package com.xiaoban.homework.organizer;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeworkOrganizerRuleRepository
    extends JpaRepository<HomeworkOrganizerRuleEntity, String> {
  List<HomeworkOrganizerRuleEntity> findByEnabledTrueOrderByPriorityDescCodeAsc();
}
