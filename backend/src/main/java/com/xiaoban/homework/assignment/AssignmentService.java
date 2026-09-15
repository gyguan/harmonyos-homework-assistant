package com.xiaoban.homework.assignment;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AssignmentService {
  private final AssignmentRepository repository;
  private final StudentService students;
  public AssignmentService(AssignmentRepository repository, StudentService students) { this.repository = repository; this.students = students; }

  @Transactional(readOnly = true)
  public List<AssignmentDtos.Response> list(UUID familyId, String studentId) {
    students.requireOwned(familyId, studentId);
    return repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId).stream().map(AssignmentDtos.Response::from).toList();
  }

  @Transactional
  public AssignmentDtos.Response create(UUID familyId, String studentId, AssignmentDtos.Create input) {
    students.requireOwned(familyId, studentId);
    AssignmentEntity existing = repository.findById(input.id()).orElse(null);
    if (existing != null) {
      if (!familyId.equals(existing.familyId) || !studentId.equals(existing.studentId)) throw new ApiExceptions.Conflict("作业 ID 冲突");
      return AssignmentDtos.Response.from(existing);
    }
    AssignmentEntity e = new AssignmentEntity(); Instant now = Instant.now();
    e.id = input.id(); e.familyId = familyId; e.studentId = studentId; e.subject = input.subject(); e.title = input.title();
    e.instruction = input.instruction(); e.textbookRef = text(input.textbookRef()); e.dueText = text(input.dueText());
    e.status = input.status(); e.sourceLabel = text(input.sourceLabel()); e.sourceExcerpt = text(input.sourceExcerpt());
    e.expectedMinutes = expectedMinutes(input.expectedMinutes());
    e.startedAtEpochMs = nonNegative(input.startedAtEpochMs());
    e.finishedAtEpochMs = nonNegative(input.finishedAtEpochMs());
    e.elapsedSeconds = nonNegative(input.elapsedSeconds());
    if ("IN_PROGRESS".equals(e.status) && e.startedAtEpochMs == 0) e.startedAtEpochMs = System.currentTimeMillis();
    e.createdAt = now; e.updatedAt = now;
    return AssignmentDtos.Response.from(repository.saveAndFlush(e));
  }

  @Transactional
  public AssignmentDtos.Response update(UUID familyId, String id, AssignmentDtos.Update input) {
    AssignmentEntity e = requireOwned(familyId, id);
    if (e.version != input.version()) throw new ApiExceptions.Conflict("作业已在其他设备更新，请刷新后重试");
    String previousStatus = e.status;
    if (input.status() != null && !AssignmentStatePolicy.canTransition(e.status, input.status())) {
      throw new ApiExceptions.BadRequest("不允许的作业状态流转: " + e.status + " -> " + input.status());
    }
    if (input.subject() != null) e.subject = input.subject();
    if (input.title() != null) e.title = input.title();
    if (input.instruction() != null) e.instruction = input.instruction();
    if (input.textbookRef() != null) e.textbookRef = input.textbookRef();
    if (input.dueText() != null) e.dueText = input.dueText();
    if (input.status() != null) e.status = input.status();
    if (input.sourceLabel() != null) e.sourceLabel = input.sourceLabel();
    if (input.sourceExcerpt() != null) e.sourceExcerpt = input.sourceExcerpt();
    if (input.expectedMinutes() != null) e.expectedMinutes = expectedMinutes(input.expectedMinutes());
    if (input.startedAtEpochMs() != null) e.startedAtEpochMs = nonNegative(input.startedAtEpochMs());
    if (input.finishedAtEpochMs() != null) e.finishedAtEpochMs = nonNegative(input.finishedAtEpochMs());
    if (input.elapsedSeconds() != null) e.elapsedSeconds = nonNegative(input.elapsedSeconds());

    long nowMs = System.currentTimeMillis();
    if (!"IN_PROGRESS".equals(previousStatus) && "IN_PROGRESS".equals(e.status) && e.startedAtEpochMs == 0) {
      e.startedAtEpochMs = nowMs;
      e.finishedAtEpochMs = 0;
      e.elapsedSeconds = 0;
    }
    if ("IN_PROGRESS".equals(previousStatus) && !"IN_PROGRESS".equals(e.status) && e.startedAtEpochMs > 0) {
      if (e.finishedAtEpochMs == 0) e.finishedAtEpochMs = nowMs;
      if (e.elapsedSeconds == 0) e.elapsedSeconds = Math.max(0, (e.finishedAtEpochMs - e.startedAtEpochMs) / 1000);
    }
    e.updatedAt = Instant.now();
    return AssignmentDtos.Response.from(repository.saveAndFlush(e));
  }

  @Transactional(readOnly = true)
  public AssignmentEntity requireOwned(UUID familyId, String id) {
    AssignmentEntity e = repository.findById(id).orElseThrow(() -> new ApiExceptions.NotFound("作业不存在"));
    if (!familyId.equals(e.familyId)) throw new ApiExceptions.NotFound("作业不存在");
    return e;
  }

  private int expectedMinutes(Integer value) { return value == null ? 20 : Math.max(1, Math.min(240, value)); }
  private long nonNegative(Long value) { return value == null ? 0 : Math.max(0, value); }
  private String text(String value) { return value == null ? "" : value; }
}
