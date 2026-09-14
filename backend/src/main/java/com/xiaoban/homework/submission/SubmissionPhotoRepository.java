package com.xiaoban.homework.submission;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubmissionPhotoRepository extends JpaRepository<SubmissionPhotoEntity, UUID> {
  List<SubmissionPhotoEntity> findBySubmissionIdOrderById(UUID submissionId);
}
