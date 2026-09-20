package com.xiaoban.homework.practice;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PracticePaperRepository extends JpaRepository<PracticePaperEntity, String> {
  Optional<PracticePaperEntity> findByPaperIdAndVersion(String paperId, int version);
}
