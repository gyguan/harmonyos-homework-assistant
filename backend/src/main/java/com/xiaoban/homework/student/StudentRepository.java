package com.xiaoban.homework.student;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StudentRepository extends JpaRepository<StudentEntity, String> {
  List<StudentEntity> findByFamilyIdOrderByCreatedAt(UUID familyId);
  long countByFamilyId(UUID familyId);
}
