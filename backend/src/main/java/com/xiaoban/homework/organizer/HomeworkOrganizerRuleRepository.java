package com.xiaoban.homework.organizer;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface HomeworkOrganizerRuleRepository
    extends JpaRepository<HomeworkOrganizerRuleEntity, String> {
  @Query("select r from homework_organizer_rule r where r.enabled = true and " +
      "(r.scope = 'GLOBAL' or (r.familyId = :familyId and r.studentId = :studentId)) " +
      "order by r.priority desc, r.code asc")
  List<HomeworkOrganizerRuleEntity> findApplicable(
      @Param("familyId") UUID familyId, @Param("studentId") String studentId);
}
