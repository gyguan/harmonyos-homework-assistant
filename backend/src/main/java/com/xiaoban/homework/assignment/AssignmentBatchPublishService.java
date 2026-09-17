package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AssignmentBatchPublishService {
  private final AssignmentService assignmentService;

  public AssignmentBatchPublishService(AssignmentService assignmentService) {
    this.assignmentService = assignmentService;
  }

  @Transactional
  public AssignmentDtos.BatchPublishResponse publish(UUID familyId, String studentId,
      AssignmentDtos.BatchPublishRequest input) {
    if (input.items() == null || input.items().isEmpty()) {
      throw new ApiExceptions.BadRequest("至少需要发布一项作业");
    }
    if (input.items().size() > 50) {
      throw new ApiExceptions.BadRequest("单次最多发布 50 项作业");
    }

    Set<String> candidateIds = new HashSet<>();
    Set<String> assignmentIds = new HashSet<>();
    for (AssignmentDtos.BatchPublishItem item : input.items()) {
      String candidateId = item.candidateId().trim();
      String expectedAssignmentId = "a-published-" + candidateId;
      if (!candidateIds.add(candidateId)) {
        throw new ApiExceptions.BadRequest("批量发布包含重复 Candidate: " + candidateId);
      }
      if (!expectedAssignmentId.equals(item.assignment().id())) {
        throw new ApiExceptions.BadRequest("Assignment ID 与 Candidate 不匹配: " + candidateId);
      }
      if (!assignmentIds.add(item.assignment().id())) {
        throw new ApiExceptions.BadRequest("批量发布包含重复 Assignment ID: " + item.assignment().id());
      }
    }

    List<AssignmentDtos.BatchPublishResult> published = new ArrayList<>();
    for (AssignmentDtos.BatchPublishItem item : input.items()) {
      AssignmentDtos.Response assignment = assignmentService.create(familyId, studentId, item.assignment());
      published.add(new AssignmentDtos.BatchPublishResult(item.candidateId(), assignment));
    }
    return new AssignmentDtos.BatchPublishResponse(true, published.size(), published);
  }
}
