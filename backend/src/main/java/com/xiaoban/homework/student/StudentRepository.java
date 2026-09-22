package com.xiaoban.homework.student;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StudentRepository extends JpaRepository<StudentEntity, String> {
  List<StudentEntity> findByFamilyIdOrderByCreatedAt(UUID familyId);
  long countByFamilyId(UUID familyId);

  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select s from student s where s.id = :id and s.familyId = :familyId")
  Optional<StudentEntity> lockOwned(
      @Param("familyId") UUID familyId, @Param("id") String id);
}
