package com.xiaoban.homework.organizer;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeworkTeacherExperienceRepository
    extends JpaRepository<HomeworkTeacherExperienceEntity, UUID> {
  List<HomeworkTeacherExperienceEntity> findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(
      UUID familyId, String studentId);
  Optional<HomeworkTeacherExperienceEntity> findBySourceFeedbackId(UUID sourceFeedbackId);
  Optional<HomeworkTeacherExperienceEntity> findByIdAndFamilyIdAndStudentId(
      UUID id, UUID familyId, String studentId);
}
