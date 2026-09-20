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
  static final String PRESET_CATALOG = "practice/preset-catalog.json";

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
    try (InputStream input = new ClassPathResource(PRESET_CATALOG).getInputStream()) {
      return mapper.readValue(input, PracticeContentCatalog.Catalog.class);
    } catch (Exception e) {
      throw new IllegalStateException("无法加载预置练习题库: " + PRESET_CATALOG, e);
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

    // Published paper versions are immutable. Startup never rewrites a version already used by Attempts.
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
