package com.xiaoban.homework.organizer;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeworkOrganizerReviewDifferenceRepository
    extends JpaRepository<HomeworkOrganizerReviewDifferenceEntity, UUID> {
  boolean existsByFamilyIdAndStudentIdAndBatchIdAndCandidateIdAndChangeTypeAndFieldName(
      UUID familyId, String studentId, String batchId, String candidateId,
      String changeType, String fieldName);
  List<HomeworkOrganizerReviewDifferenceEntity> findTop100ByFamilyIdAndStudentIdOrderByCreatedAtDesc(
      UUID familyId, String studentId);
}
