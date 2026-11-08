package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

/** 作答与笔记的写入必须先拿到练习行的写锁，否则「先查后插」必然撞唯一约束。 */
class PracticeAttemptConcurrencyGuardTest {
  private final PracticeAttemptRepository attempts = mock(PracticeAttemptRepository.class);
  private final PracticeAnswerRepository answers = mock(PracticeAnswerRepository.class);
  private final PracticeNoteRepository notes = mock(PracticeNoteRepository.class);
  private final PracticeAttemptService service = new PracticeAttemptService(
      attempts, answers, notes, mock(PracticeQuestionRepository.class),
      mock(PracticePaperRepository.class), mock(PracticeContentService.class),
      mock(StudentService.class), mock(PracticeAudiencePolicy.class), JsonMapper.builder().build());

  @Test
  void saveAnswerLocksAttemptRowBeforeInsert() {
    UUID familyId = UUID.randomUUID();
    PracticeAttemptEntity attempt = inProgressAttempt(familyId);
    when(attempts.lockByIdForUpdate(attempt.id)).thenReturn(Optional.of(attempt));
    when(answers.findByAttemptIdAndQuestionId(attempt.id, "Q1")).thenReturn(Optional.empty());

    PracticeDtos.AnswerResponse response = service.saveAnswer(
        familyId, attempt.id, "Q1", new PracticeDtos.AnswerRequest("42"));

    assertEquals("42", response.answerValue());
    verify(attempts).lockByIdForUpdate(attempt.id);
    verify(answers).save(any(PracticeAnswerEntity.class));
  }

  @Test
  void saveNoteLocksAttemptRowBeforeInsert() {
    UUID familyId = UUID.randomUUID();
    PracticeAttemptEntity attempt = inProgressAttempt(familyId);
    when(attempts.lockByIdForUpdate(attempt.id)).thenReturn(Optional.of(attempt));
    when(notes.findByAttemptIdAndQuestionId(attempt.id, "Q1")).thenReturn(Optional.empty());

    PracticeDtos.NoteResponse response = service.saveNote(
        familyId, attempt.id, "Q1", new PracticeDtos.NoteRequest("这题要注意进位"));

    assertEquals("这题要注意进位", response.content());
    verify(attempts).lockByIdForUpdate(attempt.id);
    verify(notes).save(any(PracticeNoteEntity.class));
  }

  private PracticeAttemptEntity inProgressAttempt(UUID familyId) {
    PracticeAttemptEntity attempt = new PracticeAttemptEntity();
    attempt.id = UUID.randomUUID();
    attempt.familyId = familyId;
    attempt.studentId = "student-1";
    attempt.paperId = "paper-1";
    attempt.status = "IN_PROGRESS";
    attempt.questionIdsJson = "[\"Q1\"]";
    attempt.startedAt = Instant.now();
    return attempt;
  }
}
