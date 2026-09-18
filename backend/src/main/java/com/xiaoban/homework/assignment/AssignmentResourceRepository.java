package com.xiaoban.homework.assignment;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AssignmentResourceRepository extends JpaRepository<AssignmentResourceEntity, UUID> {
  List<AssignmentResourceEntity> findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(
      UUID familyId, String assignmentId);
  void deleteByFamilyIdAndAssignmentId(UUID familyId, String assignmentId);
}
