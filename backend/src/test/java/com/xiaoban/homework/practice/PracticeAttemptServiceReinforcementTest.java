package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeAttemptServiceReinforcementTest {
  @Test
  void reinforcementStartRecoversExistingInProgressAttempt() {
    UUID familyId = UUID.randomUUID();
    String studentId = "student-1";

    PracticeAttemptRepository attempts = mock(PracticeAttemptRepository.class);
    PracticeAnswerRepository answers = mock(PracticeAnswerRepository.class);
    PracticeNoteRepository notes = mock(PracticeNoteRepository.class);
    PracticeQuestionRepository questions = mock(PracticeQuestionRepository.class);
    PracticePaperRepository papers = mock(PracticePaperRepository.class);
    PracticeContentService content = mock(PracticeContentService.class);
    StudentService students = mock(StudentService.class);
    PracticeAudiencePolicy audiencePolicy = mock(PracticeAudiencePolicy.class);

    StudentEntity student = mock(StudentEntity.class);
    PracticePaperEntity paper = new PracticePaperEntity();
    paper.paperId = "ai-reinforcement-1";
    paper.version = 1;
    paper.sourceType = "AI_REINFORCEMENT";

    PracticeQuestionEntity question = new PracticeQuestionEntity();
    question.id = "Q1";
    question.orderNo = 1;
    question.stem = "1+1=?";
    question.questionType = "NUMBER";
    question.optionsJson = "[]";
    question.answerSpec = "2";
    question.explanation = "1加1等于2";
    question.hintsJson = "[]";
    question.tagsJson = "[]";

    PracticeAttemptEntity source = new PracticeAttemptEntity();
    source.id = UUID.randomUUID();
    source.familyId = familyId;
    source.studentId = studentId;
    source.paperId = "source-paper";
    source.paperVersion = 1;
    source.status = "SUBMITTED";
    source.questionIdsJson = "[\"source-Q1\"]";
    source.startedAt = Instant.parse("2026-09-29T00:00:00Z");
    source.submittedAt = Instant.parse("2026-09-29T00:10:00Z");

    PracticeAttemptEntity existing = new PracticeAttemptEntity();
    existing.id = UUID.randomUUID();
    existing.familyId = familyId;
    existing.studentId = studentId;
    existing.paperId = paper.paperId;
    existing.paperVersion = paper.version;
    existing.attemptNo = 1;
    existing.mode = "FULL";
    existing.status = "IN_PROGRESS";
    existing.sourceAttemptId = source.id;
    existing.questionIdsJson = "[\"Q1\"]";
    existing.startedAt = Instant.parse("2026-09-29T00:20:00Z");

    when(students.requireOwned(familyId, studentId)).thenReturn(student);
    when(content.requirePaperForStudent(familyId, studentId, paper.paperId, paper.version)).thenReturn(paper);
    when(content.questions(paper)).thenReturn(List.of(question));
    when(content.questionResponse(question)).thenReturn(
        new PracticeDtos.QuestionResponse("Q1", 1, "NUMBER", "1+1=?", List.of(), List.of(), List.of()));
    when(attempts.findById(source.id)).thenReturn(Optional.of(source));
    when(attempts
        .findFirstByFamilyIdAndStudentIdAndPaperIdAndPaperVersionAndSourceAttemptIdAndStatusOrderByStartedAtDesc(
            familyId, studentId, paper.paperId, paper.version, source.id, "IN_PROGRESS"))
        .thenReturn(Optional.of(existing));
    when(answers.findByAttemptId(existing.id)).thenReturn(List.of());
    when(notes.findByAttemptId(existing.id)).thenReturn(List.of());
    when(answers.findByAttemptId(source.id)).thenReturn(List.of());
    when(notes.findByAttemptId(source.id)).thenReturn(List.of());

    PracticeAttemptService service = new PracticeAttemptService(
        attempts, answers, notes, questions, papers, content, students, audiencePolicy,
        JsonMapper.builder().build());

    PracticeDtos.AttemptResponse response = service.start(
        familyId, studentId,
        new PracticeDtos.StartRequest(paper.paperId, paper.version, source.id.toString()));

    assertEquals(existing.id.toString(), response.id());
    assertEquals(source.id.toString(), response.sourceAttemptId());
    verify(attempts, never()).save(org.mockito.ArgumentMatchers.any(PracticeAttemptEntity.class));
  }
}
