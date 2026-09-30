package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AssignmentReviewService {
  private static final Logger log = LoggerFactory.getLogger(AssignmentReviewService.class);
  private final AssignmentRepository repository;

  public AssignmentReviewService(AssignmentRepository repository) {
    this.repository = repository;
  }

  @Transactional
  public AssignmentDtos.Response review(UUID familyId, String id, AssignmentDtos.ReviewRequest input) {
    AssignmentEntity assignment = repository.findById(id)
        .orElseThrow(() -> new ApiExceptions.NotFound("作业不存在"));
    if (!familyId.equals(assignment.familyId)) throw new ApiExceptions.NotFound("作业不存在");
    if (assignment.version != input.version()) {
      throw new ApiExceptions.Conflict("作业已在其他设备更新，请刷新后重试");
    }
    if (!"SUBMITTED".equals(assignment.status)) {
      throw new ApiExceptions.BadRequest("只有已提交作业可以验收");
    }

    String decision = input.decision().trim().toUpperCase();
    String note = input.note() == null ? "" : input.note().trim();
    switch (decision) {
      case "APPROVE" -> {
        assignment.status = "COMPLETED";
        assignment.reviewNote = note;
      }
      case "RETURN_REWORK" -> {
        if (note.isEmpty()) throw new ApiExceptions.BadRequest("退回订正时必须填写原因");
        assignment.status = "NEEDS_REWORK";
        assignment.reviewNote = note;
        assignment.startedAtEpochMs = 0;
        assignment.finishedAtEpochMs = 0;
      }
      default -> throw new ApiExceptions.BadRequest("不支持的验收决定: " + input.decision());
    }
    assignment.updatedAt = Instant.now();
    AssignmentEntity saved = repository.saveAndFlush(assignment);
    log.info("assignment_review completed assignmentId={} studentId={} decision={} from=SUBMITTED to={} notePresent={}",
        saved.id, saved.studentId, decision, saved.status, !note.isEmpty());
    return AssignmentDtos.Response.from(saved);
  }
}
