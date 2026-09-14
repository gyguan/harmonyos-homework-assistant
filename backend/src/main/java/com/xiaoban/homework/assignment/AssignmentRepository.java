package com.xiaoban.homework.assignment;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AssignmentRepository extends JpaRepository<AssignmentEntity, String> {
  List<AssignmentEntity> findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(UUID familyId, String studentId);
}
