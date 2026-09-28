package com.xiaoban.homework.practice;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticePaperAudienceRepository extends JpaRepository<PracticePaperAudienceEntity, UUID> {
  boolean existsByFamilyIdAndStudentIdAndPaperKey(UUID familyId, String studentId, String paperKey);
  boolean existsByFamilyIdAndStudentId(UUID familyId, String studentId);
  List<PracticePaperAudienceEntity> findByFamilyIdAndStudentId(UUID familyId, String studentId);
  List<PracticePaperAudienceEntity> findByFamilyIdAndPaperKey(UUID familyId, String paperKey);
}
