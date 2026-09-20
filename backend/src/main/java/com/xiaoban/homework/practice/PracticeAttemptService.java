package com.xiaoban.homework.practice;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PracticeAttemptService {
  private final PracticeAttemptRepository attempts;
  private final PracticeAnswerRepository answers;
  private final PracticeQuestionRepository questionRepository;
  private final PracticeContentService content;
  private final StudentService students;
  private final JsonMapper mapper;
  private final PracticeJudgeEngine judge = new PracticeJudgeEngine();

  public PracticeAttemptService(PracticeAttemptRepository attempts, PracticeAnswerRepository answers,
      PracticeQuestionRepository questionRepository, PracticeContentService content,
      StudentService students, JsonMapper mapper) {
    this.attempts = attempts;
    this.answers = answers;
    this.questionRepository = questionRepository;
    this.content = content;
    this.students = students;
    this.mapper = mapper;
  }

  @Transactional
  public PracticeDtos.AttemptResponse start(UUID familyId, String studentId, PracticeDtos.StartRequest input) {
    students.requireOwned(familyId, studentId);
    PracticePaperEntity paper = content.requirePaper(input.paperId(), input.paperVersion());
    List<PracticeQuestionEntity> questions = content.questions(paper);
    if (questions.isEmpty()) throw new ApiExceptions.BadRequest("套卷暂无可练习题目");

    PracticeAttemptEntity attempt = new PracticeAttemptEntity();
    attempt.id = UUID.randomUUID();
    attempt.familyId = familyId;
    attempt.studentId = studentId;
    attempt.paperId = paper.paperId;
    attempt.paperVersion = paper.version;
    attempt.attemptNo = Math.toIntExact(attempts.countByFamilyIdAndStudentIdAndPaperId(
        familyId, studentId, paper.paperId) + 1);
    attempt.mode = "FULL";
    attempt.status = "IN_PROGRESS";
    attempt.questionIdsJson = writeQuestionIds(questions);
    attempt.startedAt = Instant.now();
    attempt.submittedAt = null;
    attempt.elapsedSeconds = 0;
    attempt.score = 0;
    attempt.maxScore = questions.size();
    attempt.correctCount = 0;
    attempt.wrongCount = 0;
    attempts.save(attempt);
    return response(attempt, questions);
  }

  @Transactional(readOnly = true)
  public PracticeDtos.AttemptResponse get(UUID familyId, UUID attemptId) {
    PracticeAttemptEntity attempt = requireOwned(familyId, attemptId);
    return response(attempt, questionsForAttempt(attempt));
  }

  @Transactional
  public PracticeDtos.AnswerResponse saveAnswer(UUID familyId, UUID attemptId, String questionId,
      PracticeDtos.AnswerRequest input) {
    PracticeAttemptEntity attempt = requireOwned(familyId, attemptId);
    if (!"IN_PROGRESS".equals(attempt.status)) throw new ApiExceptions.Conflict("本次练习已经交卷");
    if (!questionIds(attempt).contains(questionId)) throw new ApiExceptions.BadRequest("题目不属于本次练习");

    PracticeAnswerEntity answer = answers.findByAttemptIdAndQuestionId(attempt.id, questionId)
        .orElseGet(PracticeAnswerEntity::new);
    if (answer.id == null) {
      answer.id = UUID.randomUUID();
      answer.familyId = familyId;
      answer.attemptId = attempt.id;
      answer.questionId = questionId;
    }
    answer.answerValue = input.answerValue().trim();
    answer.isCorrect = null;
    answer.score = 0;
    answer.answeredAt = Instant.now();
    answers.save(answer);
    return answerResponse(answer);
  }

  @Transactional
  public PracticeDtos.ResultResponse submit(UUID familyId, UUID attemptId) {
    PracticeAttemptEntity attempt = requireOwned(familyId, attemptId);
    if ("SUBMITTED".equals(attempt.status)) return result(attempt);
    if (!"IN_PROGRESS".equals(attempt.status)) throw new ApiExceptions.Conflict("当前练习不能交卷");

    List<PracticeQuestionEntity> questions = questionsForAttempt(attempt);
    Map<String, PracticeAnswerEntity> answerMap = answerMap(attempt.id);
    int score = 0;
    int correct = 0;
    for (PracticeQuestionEntity question : questions) {
      PracticeAnswerEntity answer = answerMap.get(question.id);
      if (answer == null) continue;
      boolean isCorrect = judge.isCorrect(question.questionType, question.answerSpec, answer.answerValue);
      answer.isCorrect = isCorrect;
      answer.score = isCorrect ? 1 : 0;
      answers.save(answer);
      if (isCorrect) {
        score++;
        correct++;
      }
    }

    attempt.status = "SUBMITTED";
    attempt.submittedAt = Instant.now();
    attempt.elapsedSeconds = Math.max(0, Duration.between(attempt.startedAt, attempt.submittedAt).getSeconds());
    attempt.score = score;
    attempt.maxScore = questions.size();
    attempt.correctCount = correct;
    attempt.wrongCount = questions.size() - correct;
    attempts.save(attempt);
    return result(attempt);
  }

  @Transactional(readOnly = true)
  public PracticeDtos.ResultResponse result(UUID familyId, UUID attemptId) {
    PracticeAttemptEntity attempt = requireOwned(familyId, attemptId);
    if (!"SUBMITTED".equals(attempt.status)) throw new ApiExceptions.Conflict("练习尚未交卷");
    return result(attempt);
  }

  private PracticeDtos.ResultResponse result(PracticeAttemptEntity attempt) {
    List<PracticeQuestionEntity> questions = questionsForAttempt(attempt);
    Map<String, PracticeAnswerEntity> answerMap = answerMap(attempt.id);
    List<PracticeDtos.QuestionResult> results = new ArrayList<>();
    for (PracticeQuestionEntity question : questions) {
      PracticeAnswerEntity answer = answerMap.get(question.id);
      String value = answer == null ? "" : answer.answerValue;
      boolean correct = answer != null && Boolean.TRUE.equals(answer.isCorrect);
      int answerScore = answer == null ? 0 : answer.score;
      results.add(new PracticeDtos.QuestionResult(
          question.id, question.orderNo, question.stem, value, question.answerSpec,
          correct, answerScore, question.explanation));
    }
    return new PracticeDtos.ResultResponse(
        attempt.id.toString(), attempt.paperId, attempt.paperVersion, attempt.attemptNo,
        attempt.score, attempt.maxScore, attempt.correctCount, attempt.wrongCount,
        attempt.elapsedSeconds, results);
  }

  private PracticeDtos.AttemptResponse response(PracticeAttemptEntity attempt,
      List<PracticeQuestionEntity> questions) {
    List<PracticeDtos.QuestionResponse> questionResponses =
        questions.stream().map(content::questionResponse).toList();
    List<PracticeDtos.AnswerResponse> answerResponses =
        answers.findByAttemptId(attempt.id).stream().map(this::answerResponse).toList();
    return new PracticeDtos.AttemptResponse(
        attempt.id.toString(), attempt.studentId, attempt.paperId, attempt.paperVersion,
        attempt.attemptNo, attempt.mode, attempt.status, attempt.startedAt.toEpochMilli(),
        attempt.submittedAt == null ? 0 : attempt.submittedAt.toEpochMilli(), attempt.elapsedSeconds,
        answerResponses.size(), questions.size(), questionResponses, answerResponses);
  }

  private PracticeDtos.AnswerResponse answerResponse(PracticeAnswerEntity answer) {
    return new PracticeDtos.AnswerResponse(
        answer.questionId, answer.answerValue, answer.answeredAt.toEpochMilli());
  }

  private PracticeAttemptEntity requireOwned(UUID familyId, UUID attemptId) {
    PracticeAttemptEntity attempt = attempts.findById(attemptId)
        .orElseThrow(() -> new ApiExceptions.NotFound("练习实例不存在"));
    if (!familyId.equals(attempt.familyId)) throw new ApiExceptions.NotFound("练习实例不存在");
    return attempt;
  }

  private List<PracticeQuestionEntity> questionsForAttempt(PracticeAttemptEntity attempt) {
    List<String> ids = questionIds(attempt);
    Map<String, PracticeQuestionEntity> byId = new HashMap<>();
    for (PracticeQuestionEntity question : questionRepository.findAllById(ids)) byId.put(question.id, question);
    List<PracticeQuestionEntity> ordered = new ArrayList<>();
    for (String id : ids) {
      PracticeQuestionEntity question = byId.get(id);
      if (question == null) throw new IllegalStateException("练习题目已丢失: " + id);
      ordered.add(question);
    }
    return ordered;
  }

  private Map<String, PracticeAnswerEntity> answerMap(UUID attemptId) {
    Map<String, PracticeAnswerEntity> result = new HashMap<>();
    for (PracticeAnswerEntity answer : answers.findByAttemptId(attemptId)) result.put(answer.questionId, answer);
    return result;
  }

  private String writeQuestionIds(List<PracticeQuestionEntity> questions) {
    try {
      return mapper.writeValueAsString(questions.stream().map(it -> it.id).toList());
    } catch (Exception e) {
      throw new IllegalStateException("无法保存练习题目快照", e);
    }
  }

  private List<String> questionIds(PracticeAttemptEntity attempt) {
    try {
      return mapper.readValue(attempt.questionIdsJson, new TypeReference<List<String>>() {});
    } catch (Exception e) {
      throw new IllegalStateException("练习题目快照损坏", e);
    }
  }
}
