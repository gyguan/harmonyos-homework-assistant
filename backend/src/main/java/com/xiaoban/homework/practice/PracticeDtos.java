package com.xiaoban.homework.practice;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.util.List;

public final class PracticeDtos {
  private PracticeDtos() {}

  public record Option(String key, String label) {}

  public record PaperResponse(
      String id,
      int version,
      String grade,
      String subject,
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
      List<String> tags) {}

  public record StartRequest(@NotBlank String paperId, @Min(1) int paperVersion) {}

  public record AnswerRequest(@NotNull String answerValue) {}

  public record AnswerResponse(String questionId, String answerValue, long answeredAtEpochMs) {}

  public record AttemptResponse(
      String id,
      String studentId,
      String paperId,
      int paperVersion,
      int attemptNo,
      String mode,
      String status,
      long startedAtEpochMs,
      long submittedAtEpochMs,
      long elapsedSeconds,
      int answeredCount,
      int questionCount,
      List<QuestionResponse> questions,
      List<AnswerResponse> answers) {}

  public record QuestionResult(
      String questionId,
      int orderNo,
      String stem,
      String answerValue,
      String correctAnswer,
      boolean correct,
      int score,
      String explanation) {}

  public record ResultResponse(
      String attemptId,
      String paperId,
      int paperVersion,
      int attemptNo,
      int score,
      int maxScore,
      int correctCount,
      int wrongCount,
      long elapsedSeconds,
      List<QuestionResult> questions) {}
}
