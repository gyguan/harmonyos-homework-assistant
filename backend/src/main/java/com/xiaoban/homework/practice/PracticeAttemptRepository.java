package com.xiaoban.homework.practice;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PracticeAttemptRepository extends JpaRepository<PracticeAttemptEntity, UUID> {
  /**
   * 作答 / 笔记是「先查后插」，并发时两个事务都会查不到旧行再 INSERT，
   * 撞 unique(attempt_id, question_id) 变成 409。锁住本次练习的行即可把写入串行化：
   * 后一个事务等锁释放后重新查，就能看到前一个事务刚提交的行。
   */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select a from PracticeAttemptEntity a where a.id = :id")
  java.util.Optional<PracticeAttemptEntity> lockByIdForUpdate(@Param("id") UUID id);

  long countByFamilyIdAndStudentIdAndPaperId(UUID familyId, String studentId, String paperId);
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);
  java.util.Optional<PracticeAttemptEntity>
      findFirstByFamilyIdAndStudentIdAndPaperIdAndPaperVersionAndSourceAttemptIdAndStatusOrderByStartedAtDesc(
          UUID familyId, String studentId, String paperId, int paperVersion, UUID sourceAttemptId, String status);
  List<PracticeAttemptEntity> findByFamilyIdAndStudentIdOrderByStartedAtDesc(UUID familyId, String studentId);
}
