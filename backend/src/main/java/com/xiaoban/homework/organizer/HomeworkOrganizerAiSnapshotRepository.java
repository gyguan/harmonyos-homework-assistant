package com.xiaoban.homework.organizer;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeworkOrganizerAiSnapshotRepository extends JpaRepository<HomeworkOrganizerAiSnapshotEntity,UUID> {
  List<HomeworkOrganizerAiSnapshotEntity> findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
      UUID familyId, String studentId, String batchId);
}
