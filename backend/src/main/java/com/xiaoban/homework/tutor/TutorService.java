package com.xiaoban.homework.tutor;

import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TutorService {
  private static final String NOT_CONFIGURED = "AI Tutor 尚未配置模型服务；作业查看与提交不受影响。";
  private static final String TEMPORARILY_UNAVAILABLE = "AI Tutor 暂时不可用，请稍后再试；作业查看与提交不受影响。";

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
    AssignmentEntity assignment = assignments.requireOwned(familyId, assignmentId);
    Optional<TutorSessionEntity> session = sessions.findByFamilyIdAndAssignmentId(familyId, assignmentId);
    if (session.isEmpty()) return new TutorDtos.Conversation(null, model.available(), model.available() ? "" : NOT_CONFIGURED, List.of());
    return response(session.get(), model.available(), model.available() ? "" : NOT_CONFIGURED);
  }

  public TutorDtos.Conversation ask(UUID familyId, String assignmentId, TutorDtos.AskRequest request) {
    AssignmentEntity assignment = assignments.requireOwned(familyId, assignmentId);
    StudentEntity student = students.requireOwned(familyId, assignment.studentId);
    if (!model.available()) return conversationWithNotice(familyId, assignmentId, NOT_CONFIGURED);

    TutorSessionEntity session = getOrCreateSession(familyId, student.id, assignment.id);
    List<TutorMessageEntity> history = messages.findBySessionIdOrderByCreatedAt(session.id);
    TutorModelClient.TutorModelRequest modelRequest = new TutorModelClient.TutorModelRequest(
        TutorPromptBuilder.instructions(request.guidanceFirstValue(), request.directAnswerAllowedValue()),
        TutorPromptBuilder.input(student, assignment, history, request.text().trim()));
    Optional<String> reply = model.answer(modelRequest);
    if (reply.isEmpty()) return response(session, false, TEMPORARILY_UNAVAILABLE);

    Instant now = Instant.now();
    TutorMessageEntity user = new TutorMessageEntity();
    user.id = UUID.randomUUID(); user.sessionId = session.id; user.role = "USER"; user.content = request.text().trim(); user.createdAt = now;
    TutorMessageEntity assistant = new TutorMessageEntity();
    assistant.id = UUID.randomUUID(); assistant.sessionId = session.id; assistant.role = "ASSISTANT"; assistant.content = reply.get(); assistant.createdAt = now.plusMillis(1);
    messages.save(user); messages.save(assistant);
    session.updatedAt = assistant.createdAt; sessions.save(session);
    return response(session, true, "");
  }

  private TutorDtos.Conversation conversationWithNotice(UUID familyId, String assignmentId, String notice) {
    Optional<TutorSessionEntity> session = sessions.findByFamilyIdAndAssignmentId(familyId, assignmentId);
    if (session.isEmpty()) return new TutorDtos.Conversation(null, false, notice, List.of());
    return response(session.get(), false, notice);
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

  private TutorDtos.Conversation response(TutorSessionEntity session, boolean available, String notice) {
    List<TutorDtos.Message> items = messages.findBySessionIdOrderByCreatedAt(session.id).stream().map(TutorDtos.Message::from).toList();
    return new TutorDtos.Conversation(session.id, available, notice, items);
  }
}
