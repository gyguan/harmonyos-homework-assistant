package com.xiaoban.homework.tutor;

import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TutorService {
  private static final String NOT_CONFIGURED = "AI Tutor 尚未配置模型服务；作业查看与提交不受影响。";
  private static final String TEMPORARILY_UNAVAILABLE = "AI Tutor 暂时不可用，请稍后再试；作业查看与提交不受影响。";
  private static final int DEFAULT_PAGE_SIZE = 40;
  private static final int MAX_PAGE_SIZE = 80;
  private static final int MODEL_CONTEXT_MESSAGES = 20;

  private final TutorSessionRepository sessions;
  private final TutorMessageRepository messages;
  private final AssignmentService assignments;
  private final StudentService students;
  private final TutorModelClient model;

  public TutorService(TutorSessionRepository sessions, TutorMessageRepository messages, AssignmentService assignments,
      StudentService students, TutorModelClient model) {
    this.sessions = sessions; this.messages = messages; this.assignments = assignments; this.students = students; this.model = model;
  }

  @Transactional(readOnly = true)
  public TutorDtos.Conversation conversation(UUID familyId, String assignmentId) {
    return conversation(familyId, assignmentId, null, DEFAULT_PAGE_SIZE);
  }

  @Transactional(readOnly = true)
  public TutorDtos.Conversation conversation(UUID familyId, String assignmentId, Long beforeEpochMs, int limit) {
    assignments.requireOwned(familyId, assignmentId);
    Optional<TutorSessionEntity> session = sessions.findByFamilyIdAndAssignmentId(familyId, assignmentId);
    if (session.isEmpty()) {
      return new TutorDtos.Conversation(
          null, model.available(), model.available() ? "" : NOT_CONFIGURED, List.of(), false, 0L);
    }
    return response(session.get(), model.available(), model.available() ? "" : NOT_CONFIGURED,
        beforeEpochMs, limit);
  }

  public TutorDtos.Conversation ask(UUID familyId, String assignmentId, TutorDtos.AskRequest request) {
    AssignmentEntity assignment = assignments.requireOwned(familyId, assignmentId);
    StudentEntity student = students.requireOwned(familyId, assignment.studentId);
    if (!model.available()) return conversationWithNotice(familyId, assignmentId, NOT_CONFIGURED);

    TutorSessionEntity session = getOrCreateSession(familyId, student.id, assignment.id);
    List<TutorMessageEntity> history = recentHistory(session.id, MODEL_CONTEXT_MESSAGES);
    TutorModelClient.TutorModelRequest modelRequest = new TutorModelClient.TutorModelRequest(
        TutorPromptBuilder.instructions(request.guidanceFirstValue(), request.directAnswerAllowedValue()),
        TutorPromptBuilder.input(student, assignment, history, request.text().trim()));
    Optional<String> reply = model.answer(modelRequest);
    if (reply.isEmpty()) return response(session, false, TEMPORARILY_UNAVAILABLE, null, DEFAULT_PAGE_SIZE);

    Instant now = Instant.now();
    TutorMessageEntity user = new TutorMessageEntity();
    user.id = UUID.randomUUID(); user.sessionId = session.id; user.role = "USER"; user.content = request.text().trim(); user.createdAt = now;
    TutorMessageEntity assistant = new TutorMessageEntity();
    assistant.id = UUID.randomUUID(); assistant.sessionId = session.id; assistant.role = "ASSISTANT"; assistant.content = reply.get(); assistant.createdAt = now.plusMillis(1);
    messages.save(user); messages.save(assistant);
    session.updatedAt = assistant.createdAt; sessions.save(session);
    return response(session, true, "", null, DEFAULT_PAGE_SIZE);
  }

  private TutorDtos.Conversation conversationWithNotice(UUID familyId, String assignmentId, String notice) {
    Optional<TutorSessionEntity> session = sessions.findByFamilyIdAndAssignmentId(familyId, assignmentId);
    if (session.isEmpty()) return new TutorDtos.Conversation(null, false, notice, List.of(), false, 0L);
    return response(session.get(), false, notice, null, DEFAULT_PAGE_SIZE);
  }

  private TutorSessionEntity getOrCreateSession(UUID familyId, String studentId, String assignmentId) {
    Optional<TutorSessionEntity> current = sessions.findByFamilyIdAndAssignmentId(familyId, assignmentId);
    if (current.isPresent()) return current.get();
    Instant now = Instant.now();
    TutorSessionEntity session = new TutorSessionEntity();
    session.id = UUID.randomUUID(); session.familyId = familyId; session.studentId = studentId; session.assignmentId = assignmentId;
    session.createdAt = now; session.updatedAt = now;
    return sessions.save(session);
  }

  private TutorDtos.Conversation response(TutorSessionEntity session, boolean available, String notice,
      Long beforeEpochMs, int requestedLimit) {
    int limit = Math.max(1, Math.min(MAX_PAGE_SIZE, requestedLimit));
    Instant before = beforeEpochMs == null || beforeEpochMs <= 0 ? null : Instant.ofEpochMilli(beforeEpochMs);
    List<TutorMessageEntity> fetched = before == null
        ? messages.findBySessionIdOrderByCreatedAtDesc(session.id, PageRequest.of(0, limit + 1))
        : messages.findBySessionIdAndCreatedAtBeforeOrderByCreatedAtDesc(
            session.id, before, PageRequest.of(0, limit + 1));

    boolean hasMore = fetched.size() > limit;
    List<TutorMessageEntity> page = new ArrayList<>(
        fetched.subList(0, Math.min(limit, fetched.size())));
    Collections.reverse(page);
    long nextBeforeEpochMs = hasMore && !page.isEmpty() ? page.get(0).createdAt.toEpochMilli() : 0L;
    return new TutorDtos.Conversation(
        session.id, available, notice,
        page.stream().map(TutorDtos.Message::from).toList(),
        hasMore, nextBeforeEpochMs);
  }

  private List<TutorMessageEntity> recentHistory(UUID sessionId, int limit) {
    List<TutorMessageEntity> recent = new ArrayList<>(
        messages.findBySessionIdOrderByCreatedAtDesc(sessionId, PageRequest.of(0, limit)));
    Collections.reverse(recent);
    return recent;
  }
}
