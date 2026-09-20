package com.xiaoban.homework.practice;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;

public final class PracticeDtos {
  private PracticeDtos() {}

  public record Option(String key, String label) {}

  public record VisualSpecResponse(
      String type,
      String assetId,
      String layout,
      String accessibilityText) {}

  public record PaperResponse(
      String id,
      int version,
      String grade,
      String subject,
      String semester,
      String title,
      String description,
      String difficulty,
      int questionCount,
      int estimatedMinutes,
      List<String> tags,
      String sourceType) {}

  public record QuestionResponse(
      String id,
      int orderNo,
      String type,
      String stem,
      List<Option> options,
      List<String> hints,
      List<String> tags,
      VisualSpecResponse visualSpec) {}

  public record StartRequest(@NotBlank String paperId, @Min(1) int paperVersion) {}

  public record AnswerRequest(@NotNull String answerValue) {}

  public record AnswerResponse(String questionId, String answerValue, long answeredAtEpochMs) {}

  public record NoteRequest(@NotNull String content) {}

  public record NoteResponse(
      String questionId,
      String content,
      long createdAtEpochMs,
      long updatedAtEpochMs) {}

  public record PreviousAnswerResponse(String questionId, String answerValue, boolean correct) {}

  public record PreviousNoteResponse(String questionId, String content) {}

  public record AttemptResponse(
      String id,
      String studentId,
      String paperId,
      int paperVersion,
      int attemptNo,
      String mode,
      String status,
      String sourceAttemptId,
      long startedAtEpochMs,
      long submittedAtEpochMs,
      long elapsedSeconds,
      int answeredCount,
      int questionCount,
      int noteCount,
      List<QuestionResponse> questions,
      List<AnswerResponse> answers,
      List<NoteResponse> notes,
      List<PreviousAnswerResponse> previousAnswers,
      List<PreviousNoteResponse> previousNotes) {}

  public record AttemptSummary(
      String id,
      String paperId,
      int paperVersion,
      String paperTitle,
      String grade,
      String subject,
      int attemptNo,
      String mode,
      String status,
      String sourceAttemptId,
      long startedAtEpochMs,
      long submittedAtEpochMs,
      long elapsedSeconds,
      int answeredCount,
      int questionCount,
      int noteCount,
      int score,
      int maxScore,
      int correctCount,
      int wrongCount) {}

  public record QuestionResult(
      String questionId,
      int orderNo,
      String stem,
      String answerValue,
      String correctAnswer,
      boolean correct,
      int score,
      String explanation,
      String noteContent) {}

  public record ResultResponse(
      String attemptId,
      String paperId,
      int paperVersion,
      int attemptNo,
      String mode,
      int score,
      int maxScore,
      int correctCount,
      int wrongCount,
      int noteCount,
      long elapsedSeconds,
      List<QuestionResult> questions) {}
}
