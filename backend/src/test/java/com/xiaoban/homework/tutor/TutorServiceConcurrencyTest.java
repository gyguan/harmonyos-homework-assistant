package com.xiaoban.homework.tutor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Pageable;

class TutorServiceConcurrencyTest {
  @Test
  void firstQuestionRecoversWhenAnotherRequestCreatesSessionFirst() {
    TutorSessionRepository sessions = mock(TutorSessionRepository.class);
    TutorMessageRepository messages = mock(TutorMessageRepository.class);
    AssignmentService assignments = mock(AssignmentService.class);
    StudentService students = mock(StudentService.class);
    TutorModelClient model = mock(TutorModelClient.class);

    UUID familyId = UUID.randomUUID();
    AssignmentEntity assignment = mock(AssignmentEntity.class);
    assignment.id = "assignment-1";
    assignment.studentId = "student-1";
    assignment.subject = "数学";
    assignment.title = "口算";
    assignment.instruction = "完成练习";
    assignment.textbookRef = "";

    StudentEntity student = mock(StudentEntity.class);
    student.id = "student-1";
    student.grade = "二年级";
    student.className = "二（2）班";
    student.textbookSummary = "数学北师大版";

    TutorSessionEntity winner = new TutorSessionEntity();
    winner.id = UUID.randomUUID();
    winner.familyId = familyId;
    winner.studentId = "student-1";
    winner.assignmentId = "assignment-1";
    winner.createdAt = Instant.now();
    winner.updatedAt = winner.createdAt;

    when(assignments.requireOwned(familyId, "assignment-1")).thenReturn(assignment);
    when(students.requireOwned(familyId, "student-1")).thenReturn(student);
    when(model.available()).thenReturn(true);
    when(model.answer(any())).thenReturn(Optional.of("先算个位，再算十位。"));
    when(sessions.findByFamilyIdAndAssignmentId(familyId, "assignment-1"))
        .thenReturn(Optional.empty(), Optional.of(winner));
    when(sessions.saveAndFlush(any(TutorSessionEntity.class)))
        .thenThrow(new DataIntegrityViolationException("duplicate"));
    when(messages.findBySessionIdOrderByCreatedAtDesc(any(UUID.class), any(Pageable.class)))
        .thenReturn(List.of());

    TutorService service = new TutorService(sessions, messages, assignments, students, model);
    TutorDtos.Conversation result = service.ask(
        familyId, "assignment-1", new TutorDtos.AskRequest("这题怎么做？", true, false));

    assertEquals(winner.id, result.sessionId());
  }
}
