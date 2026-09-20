package com.xiaoban.homework.practice;

import tools.jackson.databind.json.JsonMapper;
import java.io.InputStream;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class PracticeContentBootstrap implements ApplicationRunner {
  static final String PRESET_ROOT = "practice/preset";
  static final String PRESET_MANIFEST = PRESET_ROOT + "/manifest.json";

  private final PracticePaperRepository papers;
  private final PracticeQuestionRepository questions;
  private final JsonMapper mapper;
  private final PracticeContentValidator validator;

  public PracticeContentBootstrap(PracticePaperRepository papers, PracticeQuestionRepository questions,
      JsonMapper mapper, PracticeContentValidator validator) {
    this.papers = papers;
    this.questions = questions;
    this.mapper = mapper;
    this.validator = validator;
  }

  @Override
  @Transactional
  public void run(ApplicationArguments args) {
    PracticeContentCatalog.Catalog catalog = loadCatalog();
    validator.validateCatalog(catalog);
    for (PracticeContentCatalog.Paper source : catalog.papers()) seed(source);
  }

  PracticeContentCatalog.Catalog loadCatalog() {
    PracticeContentCatalog.Manifest manifest = read(
        PRESET_MANIFEST, PracticeContentCatalog.Manifest.class);
    if (manifest.schemaVersion() != 1) {
      throw new IllegalStateException("预置题库 manifest schemaVersion 必须为 1");
    }
    if (manifest.files() == null || manifest.files().isEmpty()) {
      throw new IllegalStateException("预置题库 manifest 没有声明内容文件");
    }

    List<PracticeContentCatalog.Paper> merged = new ArrayList<>();
    for (String file : manifest.files()) {
      String path = PRESET_ROOT + "/" + file;
      PracticeContentCatalog.Shard shard = read(path, PracticeContentCatalog.Shard.class);
      if (shard.schemaVersion() != 1) {
        throw new IllegalStateException("题库分片 schemaVersion 非法: " + path);
      }
      if (shard.papers() == null) {
        throw new IllegalStateException("题库分片 papers 为空: " + path);
      }
      for (PracticeContentCatalog.Paper paper : shard.papers()) {
        if (!shard.grade().equals(paper.grade()) || !shard.subject().equals(paper.subject())) {
          throw new IllegalStateException(
              "题库分片与 Paper 年级/科目不一致: " + path + " -> " + paper.id());
        }
        merged.add(paper);
      }
    }
    return new PracticeContentCatalog.Catalog(
        manifest.schemaVersion(), manifest.catalogId(), manifest.generatedBy(), merged);
  }

  private <T> T read(String path, Class<T> type) {
    try (InputStream input = new ClassPathResource(path).getInputStream()) {
      return mapper.readValue(input, type);
    } catch (Exception e) {
      throw new IllegalStateException("无法加载预置练习题库: " + path, e);
    }
  }

  private void seed(PracticeContentCatalog.Paper source) {
    String paperKey = source.id() + "@" + source.version();
    PracticePaperEntity existing = papers.findByPaperIdAndVersion(source.id(), source.version()).orElse(null);
    if (existing == null) {
      papers.save(toPaper(source, paperKey));
      questions.saveAll(toQuestions(source, paperKey));
      return;
    }

    long existingQuestionCount = questions.countByPaperKey(paperKey);
    if (existingQuestionCount != source.questionCount()) {
      throw new IllegalStateException(
          "预置题库与数据库已发布版本不一致: " + paperKey
              + ", dbQuestions=" + existingQuestionCount
              + ", catalogQuestions=" + source.questionCount()
              + "。请发布新 version，不要覆盖旧版本。");
    }
  }

  private PracticePaperEntity toPaper(PracticeContentCatalog.Paper source, String paperKey) {
    PracticePaperEntity paper = new PracticePaperEntity();
    paper.paperKey = paperKey;
    paper.paperId = source.id();
    paper.version = source.version();
    paper.grade = source.grade();
    paper.subject = source.subject();
    paper.semester = source.semester();
    paper.title = source.title();
    paper.description = source.description();
    paper.difficulty = source.difficulty();
    paper.questionCount = source.questionCount();
    paper.estimatedMinutes = source.estimatedMinutes();
    paper.tagsJson = json(source.tags());
    paper.sourceType = source.sourceType();
    paper.status = source.status();
    paper.createdAt = Instant.now();
    paper.updatedAt = paper.createdAt;
    return paper;
  }

  private List<PracticeQuestionEntity> toQuestions(
      PracticeContentCatalog.Paper source, String paperKey) {
    List<PracticeQuestionEntity> result = new ArrayList<>();
    for (PracticeContentCatalog.Question item : source.questions()) {
      PracticeQuestionEntity question = new PracticeQuestionEntity();
      question.id = item.id();
      question.paperKey = paperKey;
      question.orderNo = item.orderNo();
      question.questionType = item.type();
      question.stem = item.stem();
      question.optionsJson = json(item.options());
      question.answerSpec = item.answerSpec();
      question.explanation = item.explanation();
      question.hintsJson = json(item.hints());
      question.tagsJson = json(item.tags());
      question.visualSpecJson = json(item.visualSpec() == null
          ? new PracticeContentCatalog.VisualSpec("NONE", "", "", "")
          : item.visualSpec());
      result.add(question);
    }
    return result;
  }

  private String json(Object value) {
    try {
      return mapper.writeValueAsString(value);
    } catch (Exception e) {
      throw new IllegalStateException("无法序列化练习题库内容", e);
    }
  }
}
