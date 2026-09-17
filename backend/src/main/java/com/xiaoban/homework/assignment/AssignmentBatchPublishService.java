package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class AssignmentBatchPublishService {
  private final AssignmentService assignments;
  private final AssignmentRepository repository;
  private final StudentService students;

  public AssignmentBatchPublishService(AssignmentService assignments, AssignmentRepository repository,
      StudentService students) {
    this.assignments = assignments;
    this.repository = repository;
    this.students = students;
  }

  public AssignmentDtos.BatchCreateResponse publish(UUID familyId, String studentId,
      AssignmentDtos.BatchCreateRequest input) {
    students.requireOwned(familyId, studentId);

    List<AssignmentDtos.BatchCreateItemResult> results = new ArrayList<>();
    int succeeded = 0;
    for (AssignmentDtos.Create item : input.assignments()) {
      String assignmentId = item == null || item.id() == null ? "" : item.id().trim();
      String validationError = validate(item);
      if (validationError != null) {
        results.add(new AssignmentDtos.BatchCreateItemResult(
            assignmentId, "FAILED_VALIDATION", validationError, null));
        continue;
      }

      boolean existedBefore = repository.findById(item.id()).isPresent();
      try {
        AssignmentDtos.Response response = assignments.create(familyId, studentId, item);
        results.add(new AssignmentDtos.BatchCreateItemResult(
            item.id(), existedBefore ? "EXISTING" : "CREATED", "", response));
        succeeded++;
      } catch (ApiExceptions.Conflict conflict) {
        results.add(new AssignmentDtos.BatchCreateItemResult(
            item.id(), "FAILED_CONFLICT", conflict.getMessage(), null));
      } catch (ApiExceptions.BadRequest badRequest) {
        results.add(new AssignmentDtos.BatchCreateItemResult(
            item.id(), "FAILED_VALIDATION", badRequest.getMessage(), null));
      } catch (RuntimeException unexpected) {
        results.add(new AssignmentDtos.BatchCreateItemResult(
            item.id(), "FAILED", "发布失败，请稍后重试", null));
      }
    }

    return new AssignmentDtos.BatchCreateResponse(
        input.assignments().size(), succeeded, input.assignments().size() - succeeded, results);
  }

  private String validate(AssignmentDtos.Create item) {
    if (item == null) return "发布项不能为空";
    if (item.id() == null || item.id().isBlank()) return "作业 ID 不能为空";
    if (item.subject() == null || item.subject().isBlank()) return "学科不能为空";
    if (item.title() == null || item.title().isBlank()) return "作业标题不能为空";
    if (item.instruction() == null || item.instruction().isBlank()) return "老师要求不能为空";
    if (!"NOT_STARTED".equals(item.status())) return "批量发布仅接受 NOT_STARTED 作业";
    if (item.expectedMinutes() != null && (item.expectedMinutes() < 1 || item.expectedMinutes() > 240)) {
      return "预计用时必须在 1-240 分钟之间";
    }
    return null;
  }
}
