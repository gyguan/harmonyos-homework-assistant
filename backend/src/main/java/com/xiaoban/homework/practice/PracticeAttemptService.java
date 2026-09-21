package com.xiaoban.homework.practice;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
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
  private final PracticeNoteRepository notes;
  private final PracticeQuestionRepository questionRepository;
  private final PracticePaperRepository paperRepository;
  private final PracticeContentService content;
  private final StudentService students;
  private final PracticeAudiencePolicy audiencePolicy;
  private final JsonMapper mapper;
  private final PracticeJudgeEngine judge = new PracticeJudgeEngine();

  public PracticeAttemptService(PracticeAttemptRepository attempts, PracticeAnswerRepository answers,
      PracticeNoteRepository notes, PracticeQuestionRepository questionRepository,
      PracticePaperRepository paperRepository, PracticeContentService content,
      StudentService students, PracticeAudiencePolicy audiencePolicy, JsonMapper mapper) {
    this.attempts = attempts;
    this.answers = answers;
    this.notes = notes;
    this.questionRepository = questionRepository;
    this.paperRepository = paperRepository;
    this.content = content;
    this.students = students;
    this.audiencePolicy = audiencePolicy;
    this.mapper = mapper;
  }

  @Transactional
  public PracticeDtos.AttemptResponse start(UUID familyId, String studentId, PracticeDtos.StartRequest input) {
    StudentEntity student = students.requireOwned(familyId, studentId);
    PracticePaperEntity paper = content.requirePaper(input.paperId(), input.paperVersion());
    audiencePolicy.requireFreshStartAllowed(student, paper);
    List<PracticeQuestionEntity> questions = content.questions(paper);
    if (questions.isEmpty()) throw new ApiExceptions.BadRequest("套卷暂无可练习题目");

    PracticeAttemptEntity attempt = newAttempt(
        familyId, studentId, paper.paperId, paper.version,
        writeQuestionIds(questions), null, "FULL");
    attempts.save(attempt);
    return response(attempt, questions);
  }

  @Transactional
  public PracticeDtos.AttemptResponse repeat(UUID familyId, UUID sourceAttemptId) {
    PracticeAttemptEntity source = requireSubmittedSource(familyId, sourceAttemptId);
    List<PracticeQuestionEntity> questions = questionsForAttempt(source);
    PracticeAttemptEntity repeated = newAttempt(
        familyId, source.studentId, source.paperId, source.paperVersion,
        source.questionIdsJson, source.id, "FULL");
    attempts.save(repeated);
    return response(repeated, questions);
  }

  @Transactional
  public PracticeDtos.AttemptResponse wrongOnly(UUID familyId, UUID sourceAttemptId) {
    PracticeAttemptEntity source = requireSubmittedSource(familyId, sourceAttemptId);
    List<PracticeQuestionEntity> sourceQuestions = questionsForAttempt(source);
    Map<String, PracticeAnswerEntity> sourceAnswers = answerMap(source.id);
    List<PracticeQuestionEntity> wrongQuestions = new ArrayList<>();
    for (PracticeQuestionEntity question : sourceQuestions) {
      PracticeAnswerEntity answer = sourceAnswers.get(question.id);
      if (answer == null || !Boolean.TRUE.equals(answer.isCorrect)) wrongQuestions.add(question);
    }
    if (wrongQuestions.isEmpty()) throw new ApiExceptions.Conflict("本次练习没有错题，无需专项重练");

    PracticeAttemptEntity repeated = newAttempt(
        familyId, source.studentId, source.paperId, source.paperVersion,
        writeQuestionIds(wrongQuestions), source.id, "WRONG_ONLY");
    attempts.save(repeated);
    return response(repeated, wrongQuestions);
  }

  @Transactional(readOnly = true)
  public List<PracticeDtos.AttemptSummary> history(UUID familyId, String studentId, String paperId) {
    students.requireOwned(familyId, studentId);
    List<PracticeDtos.AttemptSummary> result = new ArrayList<>();
    for (PracticeAttemptEntity attempt :
        attempts.findByFamilyIdAndStudentIdOrderByStartedAtDesc(familyId, studentId)) {
      if (paperId != null && !paperId.isBlank() && !paperId.equals(attempt.paperId)) continue;
      PracticePaperEntity paper = paperRepository.findByPaperIdAndVersion(
          attempt.paperId, attempt.paperVersion).orElse(null);
      String title = paper == null ? attempt.paperId : paper.title;
      String grade = paper == null ? "" : paper.grade;
      String subject = paper == null ? "" : paper.subject;
      result.add(new PracticeDtos.AttemptSummary(
          attempt.id.toString(), attempt.paperId, attempt.paperVersion, title, grade, subject,
          attempt.attemptNo, attempt.mode, attempt.status,
          attempt.sourceAttemptId == null ? "" : attempt.sourceAttemptId.toString(),
          attempt.startedAt.toEpochMilli(),
          attempt.submittedAt == null ? 0 : attempt.submittedAt.toEpochMilli(),
          attempt.elapsedSeconds, Math.toIntExact(answers.countByAttemptId(attempt.id)),
          questionIds(attempt).size(), Math.toIntExact(notes.countByAttemptId(attempt.id)),
          attempt.score, attempt.maxScore, attempt.correctCount, attempt.wrongCount));
    }
    return result;
  }

  @Transactional(readOnly = true)
  public PracticeDtos.AttemptResponse get(UUID familyId, UUID attemptId) {
    PracticeAttemptEntity attempt = requireOwned(familyId, attemptId);
    return response(attempt, questionsForAttempt(attempt));
  }

  @Transactional
  public PracticeDtos.AnswerResponse saveAnswer(UUID familyId, UUID attemptId, String questionId,
      PracticeDtos.AnswerRequest input) {
    PracticeAttemptEntity attempt = requireEditable(familyId, attemptId);
    requireQuestion(attempt, questionId);

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
  public PracticeDtos.NoteResponse saveNote(UUID familyId, UUID attemptId, String questionId,
      PracticeDtos.NoteRequest input) {
    PracticeAttemptEntity attempt = requireEditable(familyId, attemptId);
    requireQuestion(attempt, questionId);
    String content = input.content().trim();
    if (content.isEmpty()) throw new ApiExceptions.BadRequest("笔记内容不能为空");
    if (content.length() > 500) throw new ApiExceptions.BadRequest("单题笔记不能超过500字");

    Instant now = Instant.now();
    PracticeNoteEntity note = notes.findByAttemptIdAndQuestionId(attempt.id, questionId)
        .orElseGet(PracticeNoteEntity::new);
    if (note.id == null) {
      note.id = UUID.randomUUID();
      note.familyId = familyId;
      note.studentId = attempt.studentId;
      note.attemptId = attempt.id;
      note.questionId = questionId;
      note.createdAt = now;
    }
    note.content = content;
    note.updatedAt = now;
    notes.save(note);
    return noteResponse(note);
  }

  @Transactional
  public void deleteNote(UUID familyId, UUID attemptId, String questionId) {
    PracticeAttemptEntity attempt = requireEditable(familyId, attemptId);
    requireQuestion(attempt, questionId);
    PracticeNoteEntity note = notes.findByAttemptIdAndQuestionId(attempt.id, questionId).orElse(null);
    if (note != null) notes.delete(note);
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

  private PracticeAttemptEntity newAttempt(UUID familyId, String studentId, String paperId,
      int paperVersion, String questionIdsJson, UUID sourceAttemptId, String mode) {
    PracticeAttemptEntity attempt = new PracticeAttemptEntity();
    attempt.id = UUID.randomUUID();
    attempt.familyId = familyId;
    attempt.studentId = studentId;
    attempt.paperId = paperId;
    attempt.paperVersion = paperVersion;
    attempt.attemptNo = Math.toIntExact(attempts.countByFamilyIdAndStudentIdAndPaperId(
        familyId, studentId, paperId) + 1);
    attempt.mode = mode;
    attempt.status = "IN_PROGRESS";
    attempt.sourceAttemptId = sourceAttemptId;
    attempt.questionIdsJson = questionIdsJson;
    attempt.startedAt = Instant.now();
    attempt.submittedAt = null;
    attempt.elapsedSeconds = 0;
    attempt.score = 0;
    attempt.maxScore = questionIdsFromJson(questionIdsJson).size();
    attempt.correctCount = 0;
    attempt.wrongCount = 0;
    return attempt;
  }

  private PracticeDtos.ResultResponse result(PracticeAttemptEntity attempt) {
    List<PracticeQuestionEntity> questions = questionsForAttempt(attempt);
    Map<String, PracticeAnswerEntity> answerMap = answerMap(attempt.id);
    Map<String, PracticeNoteEntity> noteMap = noteMap(attempt.id);
    List<PracticeDtos.QuestionResult> results = new ArrayList<>();
    for (PracticeQuestionEntity question : questions) {
      PracticeAnswerEntity answer = answerMap.get(question.id);
      PracticeNoteEntity note = noteMap.get(question.id);
      String value = answer == null ? "" : answer.answerValue;
      boolean correct = answer != null && Boolean.TRUE.equals(answer.isCorrect);
      int answerScore = answer == null ? 0 : answer.score;
      results.add(new PracticeDtos.QuestionResult(
          question.id, question.orderNo, question.stem, value, question.answerSpec,
          correct, answerScore, question.explanation, note == null ? "" : note.content));
    }
    return new PracticeDtos.ResultResponse(
        attempt.id.toString(), attempt.paperId, attempt.paperVersion, attempt.attemptNo,
        attempt.mode, attempt.score, attempt.maxScore, attempt.correctCount, attempt.wrongCount,
        Math.toIntExact(notes.countByAttemptId(attempt.id)), attempt.elapsedSeconds, results);
  }

  private PracticeDtos.AttemptResponse response(PracticeAttemptEntity attempt,
      List<PracticeQuestionEntity> questions) {
    List<PracticeDtos.QuestionResponse> questionResponses =
        questions.stream().map(content::questionResponse).toList();
    List<PracticeDtos.AnswerResponse> answerResponses =
        answers.findByAttemptId(attempt.id).stream().map(this::answerResponse).toList();
    List<PracticeDtos.NoteResponse> noteResponses =
        notes.findByAttemptId(attempt.id).stream().map(this::noteResponse).toList();
    return new PracticeDtos.AttemptResponse(
        attempt.id.toString(), attempt.studentId, attempt.paperId, attempt.paperVersion,
        attempt.attemptNo, attempt.mode, attempt.status,
        attempt.sourceAttemptId == null ? "" : attempt.sourceAttemptId.toString(),
        attempt.startedAt.toEpochMilli(),
        attempt.submittedAt == null ? 0 : attempt.submittedAt.toEpochMilli(), attempt.elapsedSeconds,
        answerResponses.size(), questions.size(), noteResponses.size(),
        questionResponses, answerResponses, noteResponses,
        previousAnswers(attempt), previousNotes(attempt));
  }

  private List<PracticeDtos.PreviousAnswerResponse> previousAnswers(PracticeAttemptEntity attempt) {
    PracticeAttemptEntity source = sourceAttempt(attempt);
    if (source == null) return List.of();
    List<String> currentQuestionIds = questionIds(attempt);
    List<PracticeDtos.PreviousAnswerResponse> result = new ArrayList<>();
    for (PracticeAnswerEntity answer : answers.findByAttemptId(source.id)) {
      if (!currentQuestionIds.contains(answer.questionId)) continue;
      result.add(new PracticeDtos.PreviousAnswerResponse(
          answer.questionId, answer.answerValue, Boolean.TRUE.equals(answer.isCorrect)));
    }
    return result;
  }

  private List<PracticeDtos.PreviousNoteResponse> previousNotes(PracticeAttemptEntity attempt) {
    PracticeAttemptEntity source = sourceAttempt(attempt);
    if (source == null) return List.of();
    List<String> currentQuestionIds = questionIds(attempt);
    List<PracticeDtos.PreviousNoteResponse> result = new ArrayList<>();
    for (PracticeNoteEntity note : notes.findByAttemptId(source.id)) {
      if (!currentQuestionIds.contains(note.questionId)) continue;
      result.add(new PracticeDtos.PreviousNoteResponse(note.questionId, note.content));
    }
    return result;
  }

  private PracticeAttemptEntity sourceAttempt(PracticeAttemptEntity attempt) {
    if (attempt.sourceAttemptId == null) return null;
    PracticeAttemptEntity source = attempts.findById(attempt.sourceAttemptId).orElse(null);
    if (source == null || !attempt.familyId.equals(source.familyId) || !"SUBMITTED".equals(source.status)) {
      return null;
    }
    return source;
  }

  private PracticeDtos.AnswerResponse answerResponse(PracticeAnswerEntity answer) {
    return new PracticeDtos.AnswerResponse(
        answer.questionId, answer.answerValue, answer.answeredAt.toEpochMilli());
  }

  private PracticeDtos.NoteResponse noteResponse(PracticeNoteEntity note) {
    return new PracticeDtos.NoteResponse(
        note.questionId, note.content, note.createdAt.toEpochMilli(), note.updatedAt.toEpochMilli());
  }

  private PracticeAttemptEntity requireSubmittedSource(UUID familyId, UUID attemptId) {
    PracticeAttemptEntity source = requireOwned(familyId, attemptId);
    if (!"SUBMITTED".equals(source.status)) throw new ApiExceptions.Conflict("只有已交卷练习才能再次练习");
    return source;
  }

  private PracticeAttemptEntity requireEditable(UUID familyId, UUID attemptId) {
    PracticeAttemptEntity attempt = requireOwned(familyId, attemptId);
    if (!"IN_PROGRESS".equals(attempt.status)) throw new ApiExceptions.Conflict("本次练习已经交卷");
    return attempt;
  }

  private PracticeAttemptEntity requireOwned(UUID familyId, UUID attemptId) {
    PracticeAttemptEntity attempt = attempts.findById(attemptId)
        .orElseThrow(() -> new ApiExceptions.NotFound("练习实例不存在"));
    if (!familyId.equals(attempt.familyId)) throw new ApiExceptions.NotFound("练习实例不存在");
    return attempt;
  }

  private void requireQuestion(PracticeAttemptEntity attempt, String questionId) {
    if (!questionIds(attempt).contains(questionId)) throw new ApiExceptions.BadRequest("题目不属于本次练习");
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

  private Map<String, PracticeNoteEntity> noteMap(UUID attemptId) {
    Map<String, PracticeNoteEntity> result = new HashMap<>();
    for (PracticeNoteEntity note : notes.findByAttemptId(attemptId)) result.put(note.questionId, note);
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
    return questionIdsFromJson(attempt.questionIdsJson);
  }

  private List<String> questionIdsFromJson(String json) {
    try {
      return mapper.readValue(json, new TypeReference<List<String>>() {});
    } catch (Exception e) {
      throw new IllegalStateException("练习题目快照损坏", e);
    }
  }
}
