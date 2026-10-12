package com.xiaoban.homework.submission;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubmissionResourceRepository extends JpaRepository<SubmissionResourceEntity, UUID> {
  List<SubmissionResourceEntity> findBySubmissionIdOrderBySortOrderAscIdAsc(UUID submissionId);
}
