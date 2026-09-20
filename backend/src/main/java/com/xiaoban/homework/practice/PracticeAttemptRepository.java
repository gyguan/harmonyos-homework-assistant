package com.xiaoban.homework.practice;

import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticeAttemptRepository extends JpaRepository<PracticeAttemptEntity, UUID> {
  long countByFamilyIdAndStudentIdAndPaperId(UUID familyId, String studentId, String paperId);
}
