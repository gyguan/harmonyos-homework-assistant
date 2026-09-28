package com.xiaoban.homework.practice;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PracticePaperRepository extends JpaRepository<PracticePaperEntity, String> {
  Optional<PracticePaperEntity> findByPaperIdAndVersion(String paperId, int version);

  @Query(value = """
      select p.*
      from practice_paper p
      left join practice_paper_audience a
        on a.paper_key = p.paper_key
       and a.family_id = :familyId
       and a.student_id = :studentId
      where p.status = 'PUBLISHED'
        and (p.family_id is null or (p.family_id = :familyId and a.id is not null))
        and (:grade = '' or upper(p.grade) = upper(:grade))
        and (:subject = '' or upper(p.subject) = upper(:subject))
        and (:semester = '' or upper(:semester) = 'ALL'
             or upper(p.semester) = 'ALL' or upper(p.semester) = upper(:semester))
        and (:track = '' or upper(:track) = 'ALL' or upper(p.track) = upper(:track))
      order by case when p.source_type = 'AI_GENERATED' then 0 else 1 end,
               p.updated_at desc nulls last,
               p.title
      """, nativeQuery = true)
  List<PracticePaperEntity> findVisibleForStudent(
      @Param("familyId") UUID familyId,
      @Param("studentId") String studentId,
      @Param("grade") String grade,
      @Param("subject") String subject,
      @Param("semester") String semester,
      @Param("track") String track);
}
