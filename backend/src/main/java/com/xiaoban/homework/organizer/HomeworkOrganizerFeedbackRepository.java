package com.xiaoban.homework.organizer;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeworkOrganizerFeedbackRepository
    extends JpaRepository<HomeworkOrganizerFeedbackEntity, UUID> {
  Optional<HomeworkOrganizerFeedbackEntity> findByFamilyIdAndStudentIdAndClientRequestId(
      UUID familyId, String studentId, String clientRequestId);
  Optional<HomeworkOrganizerFeedbackEntity> findByIdAndFamilyIdAndStudentId(
      UUID id, UUID familyId, String studentId);
  List<HomeworkOrganizerFeedbackEntity> findTop50ByFamilyIdAndStudentIdOrderByCreatedAtDesc(
      UUID familyId, String studentId);
}
