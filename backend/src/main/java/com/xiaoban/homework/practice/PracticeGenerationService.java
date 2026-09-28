package com.xiaoban.homework.practice;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

@Service
public class PracticeGenerationService {
  private static final Set<String> SUBJECTS = Set.of("CHINESE", "MATH", "ENGLISH");
  private static final Set<String> TRACKS = Set.of("TEXTBOOK_SYNC", "EXTRACURRICULAR");
  private static final Set<String> DIFFICULTIES = Set.of("L1", "L2", "L3");

  private final PracticeGenerationRepository generations;
  private final PracticePaperRepository papers;
  private final PracticeQuestionRepository questions;
  private final StudentService students;
  private final PracticeAudiencePolicy audiencePolicy;
  private final PracticeGenerationModelClient model;
  private final PracticeGeneratedContentValidator validator;
  private final PracticeContentService content;
  private final JsonMapper mapper;

  public PracticeGenerationService(
      PracticeGenerationRepository generations,
      PracticePaperRepository papers,
      PracticeQuestionRepository questions,
      StudentService students,
      PracticeAudiencePolicy audiencePolicy,
      PracticeGenerationModelClient model,
      PracticeGeneratedContentValidator validator,
      PracticeContentService content,
      JsonMapper mapper) {
    this.generations = generations;
    this.papers = papers;
    this.questions = questions;
    this.students = students;
    this.audiencePolicy = audiencePolicy;
    this.model = model;
    this.validator = validator;
    this.content = content;
    this.mapper = mapper;
  }

  public PracticeGenerationDtos.GenerationResponse generate(
      UUID familyId, String studentId, PracticeGenerationDtos.GenerateRequest input) {
    StudentEntity student = students.requireOwned(familyId, studentId);
    String subject = normalize(input.subject());
    String track = normalize(input.track());
    String difficulty = normalize(input.difficulty());
    if (!SUBJECTS.contains(subject)) throw new ApiExceptions.BadRequest("AI出题暂只支持语文、数学、英语");
    if (!TRACKS.contains(track)) throw new ApiExceptions.BadRequest("不支持的题库类型");
    if (!DIFFICULTIES.contains(difficulty)) throw new ApiExceptions.BadRequest("不支持的练习难度");
    String requirement = input.requirement().trim();
    if (requirement.length() > 500) throw new ApiExceptions.BadRequest("训练要求不能超过500字");

    String grade = audiencePolicy.gradeCode(student.grade);
    String semester = audiencePolicy.semesterCode(student.semester);
    if (grade.isBlank() || semester.isBlank()) {
      throw new ApiExceptions.BadRequest("请先完善孩子的年级和学期信息");
    }
    if ("TEXTBOOK_SYNC".equals(track)
        && (student.textbookSummary == null || student.textbookSummary.isBlank())) {
      throw new ApiExceptions.BadRequest("教材同步出题前请先配置孩子的教材信息");
    }
    if (!model.available()) {
      throw new ApiExceptions.ServiceUnavailable("AI出题服务尚未配置");
    }

    UUID generationId = UUID.randomUUID();
    String paperId = "ai-" + generationId;
    Instant now = Instant.now();
    PracticeGenerationEntity generation = new PracticeGenerationEntity();
    generation.id = generationId;
    generation.familyId = familyId;
    generation.studentId = studentId;
    generation.subject = subject;
    generation.semester = semester;
    generation.track = track;
    generation.difficulty = difficulty;
    generation.questionCount = input.questionCount();
    generation.requirement = requirement;
    generation.status = "GENERATING";
    generation.generatedJson = null;
    generation.paperId = paperId;
    generation.paperVersion = 1;
    generation.model = model.model();
    generation.errorMessage = "";
    generation.createdAt = now;
    generation.updatedAt = now;
    generations.saveAndFlush(generation);

    PracticeGenerationDtos.GenerateRequest normalized =
        new PracticeGenerationDtos.GenerateRequest(
            subject, track, difficulty, input.questionCount(), requirement);
    PracticeContentCatalog.Paper generated =
        model.generate(student, paperId, grade, semester, normalized).orElse(null);
    if (generated == null) {
      fail(generation, "AI未返回可解析的练习内容");
      throw new ApiExceptions.ServiceUnavailable("AI出题失败，请稍后重试");
    }

    try {
      validator.validate(generated, input.questionCount());
      generation.generatedJson = mapper.writeValueAsString(generated);
      generation.status = "READY";
      generation.errorMessage = "";
      generation.updatedAt = Instant.now();
      generations.saveAndFlush(generation);
      return response(generation, generated);
    } catch (Exception error) {
      fail(generation, safe(error.getMessage()));
      throw new ApiExceptions.ServiceUnavailable(
          "AI生成内容未通过质量校验，请重新生成：" + safe(error.getMessage()));
    }
  }

  @Transactional(readOnly = true)
  public PracticeGenerationDtos.GenerationResponse get(UUID familyId, UUID generationId) {
    PracticeGenerationEntity generation = requireOwned(familyId, generationId);
    return response(generation, readDraft(generation));
  }

  @Transactional
  public PracticeGenerationDtos.PublishResponse publish(UUID familyId, UUID generationId) {
    PracticeGenerationEntity generation = requireOwned(familyId, generationId);
    if ("PUBLISHED".equals(generation.status)) {
      PracticePaperEntity existing = content.requirePaperForStudent(
          familyId, generation.studentId, generation.paperId, generation.paperVersion);
      return new PracticeGenerationDtos.PublishResponse(
          generation.id.toString(), generation.status, content.response(existing));
    }
    if (!"READY".equals(generation.status)) {
      throw new ApiExceptions.Conflict("只有已生成并通过校验的练习才能发布");
    }

    PracticeContentCatalog.Paper draft = readDraft(generation);
    if (draft == null) throw new ApiExceptions.Conflict("练习草稿内容不存在");
    validator.validate(draft, generation.questionCount);

    if (papers.findByPaperIdAndVersion(draft.id(), draft.version()).isPresent()) {
      throw new ApiExceptions.Conflict("练习套卷已存在");
    }

    PracticePaperEntity paper = new PracticePaperEntity();
    paper.paperKey = draft.id() + "@" + draft.version();
    paper.paperId = draft.id();
    paper.version = draft.version();
    paper.familyId = generation.familyId;
    paper.studentId = generation.studentId;
    paper.grade = draft.grade();
    paper.subject = draft.subject();
    paper.semester = draft.semester();
    paper.track = draft.track();
    paper.title = draft.title();
    paper.description = draft.description();
    paper.difficulty = draft.difficulty();
    paper.questionCount = draft.questionCount();
    paper.estimatedMinutes = draft.estimatedMinutes();
    paper.tagsJson = json(draft.tags());
    paper.sourceType = "AI_GENERATED";
    paper.status = "PUBLISHED";
    paper.createdAt = Instant.now();
    paper.updatedAt = paper.createdAt;
    papers.saveAndFlush(paper);

    List<PracticeQuestionEntity> entities = new ArrayList<>();
    for (PracticeContentCatalog.Question item : draft.questions()) {
      PracticeQuestionEntity question = new PracticeQuestionEntity();
      question.id = item.id();
      question.paperKey = paper.paperKey;
      question.orderNo = item.orderNo();
      question.questionType = item.type();
      question.stem = item.stem();
      question.optionsJson = json(item.options());
      question.answerSpec = item.answerSpec();
      question.explanation = item.explanation();
      question.hintsJson = json(item.hints());
      question.tagsJson = json(item.tags());
      entities.add(question);
    }
    questions.saveAll(entities);

    generation.status = "PUBLISHED";
    generation.updatedAt = Instant.now();
    generations.save(generation);
    return new PracticeGenerationDtos.PublishResponse(
        generation.id.toString(), generation.status, content.response(paper));
  }

  private PracticeGenerationDtos.GenerationResponse response(
      PracticeGenerationEntity generation, PracticeContentCatalog.Paper paper) {
    return new PracticeGenerationDtos.GenerationResponse(
        generation.id.toString(),
        generation.status,
        paper == null ? null : draftResponse(paper),
        generation.errorMessage == null ? "" : generation.errorMessage);
  }

  private PracticeGenerationDtos.DraftPaper draftResponse(PracticeContentCatalog.Paper paper) {
    List<PracticeGenerationDtos.DraftQuestion> questions = new ArrayList<>();
    for (PracticeContentCatalog.Question item : paper.questions()) {
      questions.add(new PracticeGenerationDtos.DraftQuestion(
          item.id(), item.orderNo(), item.type(), item.stem(),
          item.options().stream().map(option ->
              new PracticeDtos.Option(option.key(), option.label())).toList(),
          item.answerSpec(), item.explanation(), item.hints(), item.tags()));
    }
    return new PracticeGenerationDtos.DraftPaper(
        paper.id(), paper.version(), paper.grade(), paper.subject(), paper.semester(),
        paper.track(), paper.title(), paper.description(), paper.difficulty(),
        paper.questionCount(), paper.estimatedMinutes(), paper.tags(),
        paper.sourceType(), questions);
  }

  private PracticeContentCatalog.Paper readDraft(PracticeGenerationEntity generation) {
    if (generation.generatedJson == null || generation.generatedJson.isBlank()) return null;
    try {
      return mapper.readValue(generation.generatedJson, PracticeContentCatalog.Paper.class);
    } catch (Exception error) {
      throw new IllegalStateException("AI练习草稿损坏", error);
    }
  }

  private PracticeGenerationEntity requireOwned(UUID familyId, UUID generationId) {
    PracticeGenerationEntity generation = generations.findById(generationId)
        .orElseThrow(() -> new ApiExceptions.NotFound("AI练习生成记录不存在"));
    if (!familyId.equals(generation.familyId)) {
      throw new ApiExceptions.NotFound("AI练习生成记录不存在");
    }
    return generation;
  }

  private void fail(PracticeGenerationEntity generation, String message) {
    generation.status = "FAILED";
    generation.errorMessage = message;
    generation.updatedAt = Instant.now();
    generations.saveAndFlush(generation);
  }

  private String json(Object value) {
    try {
      return mapper.writeValueAsString(value);
    } catch (Exception error) {
      throw new IllegalStateException("无法保存AI练习内容", error);
    }
  }

  private static String normalize(String value) {
    return value == null ? "" : value.trim().toUpperCase();
  }

  private static String safe(String value) {
    if (value == null || value.isBlank()) return "未知校验错误";
    String compact = value.replace('\r', ' ').replace('\n', ' ').trim();
    return compact.length() <= 300 ? compact : compact.substring(0, 300);
  }
}
