package com.xiaoban.homework.practice;

import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;
import com.xiaoban.homework.common.ApiExceptions;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PracticeContentService {
  private final PracticePaperRepository papers;
  private final PracticeQuestionRepository questions;
  private final JsonMapper mapper;

  public PracticeContentService(PracticePaperRepository papers, PracticeQuestionRepository questions,
      JsonMapper mapper) {
    this.papers = papers;
    this.questions = questions;
    this.mapper = mapper;
  }

  @Transactional(readOnly = true)
  public PracticePaperEntity requirePaper(String paperId, int version) {
    PracticePaperEntity paper = papers.findByPaperIdAndVersion(paperId, version)
        .orElseThrow(() -> new ApiExceptions.NotFound("练习套卷不存在"));
    if (!"PUBLISHED".equals(paper.status)) throw new ApiExceptions.NotFound("练习套卷不存在");
    return paper;
  }

  @Transactional(readOnly = true)
  public List<PracticeQuestionEntity> questions(PracticePaperEntity paper) {
    return questions.findByPaperKeyOrderByOrderNo(paper.paperKey);
  }

  public PracticeDtos.PaperResponse response(PracticePaperEntity paper) {
    return new PracticeDtos.PaperResponse(
        paper.paperId, paper.version, paper.grade, paper.subject, paper.semester, paper.track, paper.title, paper.description,
        paper.difficulty, paper.questionCount, paper.estimatedMinutes,
        strings(paper.tagsJson), paper.sourceType);
  }

  public PracticeDtos.QuestionResponse questionResponse(PracticeQuestionEntity question) {
    return new PracticeDtos.QuestionResponse(
        question.id, question.orderNo, question.questionType, question.stem,
        options(question.optionsJson), strings(question.hintsJson), strings(question.tagsJson));
  }

  private List<String> strings(String json) {
    try {
      return mapper.readValue(json, new TypeReference<List<String>>() {});
    } catch (Exception e) {
      throw new IllegalStateException("练习内容 JSON 损坏", e);
    }
  }

  private List<PracticeDtos.Option> options(String json) {
    try {
      return mapper.readValue(json, new TypeReference<List<PracticeDtos.Option>>() {});
    } catch (Exception e) {
      throw new IllegalStateException("练习选项 JSON 损坏", e);
    }
  }
}
