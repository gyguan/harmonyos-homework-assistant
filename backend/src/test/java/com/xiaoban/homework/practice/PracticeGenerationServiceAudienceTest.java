package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentDtos;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeGenerationServiceAudienceTest {
  @Test
  void selectedStudentsShareOnePublishedPaperWithTwoAudienceRows() throws Exception {
    UUID familyId = UUID.randomUUID();
    PracticeGenerationRepository generations = mock(PracticeGenerationRepository.class);
    PracticePaperRepository papers = mock(PracticePaperRepository.class);
    PracticeQuestionRepository questions = mock(PracticeQuestionRepository.class);
    PracticePaperAudienceRepository audiences = mock(PracticePaperAudienceRepository.class);
    StudentService students = mock(StudentService.class);
    PracticeAudiencePolicy audiencePolicy = mock(PracticeAudiencePolicy.class);
    PracticeGenerationModelClient model = mock(PracticeGenerationModelClient.class);
    PracticeGeneratedContentValidator validator = mock(PracticeGeneratedContentValidator.class);
    PracticeContentService content = mock(PracticeContentService.class);
    JsonMapper mapper = JsonMapper.builder().build();

    PracticeGenerationEntity generation = generation(familyId, mapper);
    when(generations.lockByIdAndFamilyId(generation.id, familyId)).thenReturn(Optional.of(generation));
    when(papers.findByPaperIdAndVersion("ai-test", 1)).thenReturn(Optional.empty());

    StudentEntity reference = student("ref", "小宇", "二年级", "上学期", "人教版数学二年级上册");
    StudentEntity second = student("second", "小明", "二年级", "上学期", "人教版数学二年级上册");
    when(students.requireOwned(familyId, "ref")).thenReturn(reference);
    when(students.requireOwned(familyId, "second")).thenReturn(second);
    when(audiencePolicy.gradeCode("二年级")).thenReturn("G2");
    when(audiencePolicy.semesterCode("上学期")).thenReturn("S1");
    when(content.response(any(PracticePaperEntity.class))).thenReturn(paperResponse());

    PracticeGenerationService service = new PracticeGenerationService(
        generations, papers, questions, audiences, students, audiencePolicy,
        model, mock(PracticeGenerationReviewClient.class), validator, content, mapper);

    PracticeGenerationDtos.PublishResponse response = service.publish(
        familyId,
        generation.id,
        new PracticeGenerationDtos.PublishRequest("SELECTED", List.of("ref", "second")));

    assertEquals(List.of("ref", "second"), response.targetStudentIds());
    verify(papers).saveAndFlush(any(PracticePaperEntity.class));
    verify(audiences).saveAll(org.mockito.ArgumentMatchers.argThat(items -> {
      int count = 0;
      for (PracticePaperAudienceEntity ignored : items) count++;
      return count == 2;
    }));
  }

  @Test
  void allScopePublishesToAllCurrentCompatibleStudents() throws Exception {
    UUID familyId = UUID.randomUUID();
    PracticeGenerationRepository generations = mock(PracticeGenerationRepository.class);
    PracticePaperRepository papers = mock(PracticePaperRepository.class);
    PracticeQuestionRepository questions = mock(PracticeQuestionRepository.class);
    PracticePaperAudienceRepository audiences = mock(PracticePaperAudienceRepository.class);
    StudentService students = mock(StudentService.class);
    PracticeAudiencePolicy audiencePolicy = mock(PracticeAudiencePolicy.class);
    JsonMapper mapper = JsonMapper.builder().build();

    PracticeGenerationEntity generation = generation(familyId, mapper);
    when(generations.lockByIdAndFamilyId(generation.id, familyId)).thenReturn(Optional.of(generation));
    when(papers.findByPaperIdAndVersion("ai-test", 1)).thenReturn(Optional.empty());

    StudentEntity reference = student("ref", "小宇", "二年级", "上学期", "人教版数学二年级上册");
    StudentEntity second = student("second", "小明", "二年级", "上学期", "人教版数学二年级上册");
    when(students.list(familyId)).thenReturn(List.of(
        new StudentDtos.Response("ref", "小宇", "二年级", "", "上学期", "人教版数学二年级上册"),
        new StudentDtos.Response("second", "小明", "二年级", "", "上学期", "人教版数学二年级上册")));
    when(students.requireOwned(familyId, "ref")).thenReturn(reference);
    when(students.requireOwned(familyId, "second")).thenReturn(second);
    when(audiencePolicy.gradeCode("二年级")).thenReturn("G2");
    when(audiencePolicy.semesterCode("上学期")).thenReturn("S1");
    PracticeContentService content = mock(PracticeContentService.class);
    when(content.response(any(PracticePaperEntity.class))).thenReturn(paperResponse());
    PracticeGenerationService service = new PracticeGenerationService(
        generations, papers, questions, audiences, students, audiencePolicy,
        mock(PracticeGenerationModelClient.class),
        mock(PracticeGenerationReviewClient.class),
        mock(PracticeGeneratedContentValidator.class),
        content, mapper);

    PracticeGenerationDtos.PublishResponse response = service.publish(
        familyId,
        generation.id,
        new PracticeGenerationDtos.PublishRequest("ALL", List.of()));

    assertEquals(List.of("ref", "second"), response.targetStudentIds());
    verify(audiences).saveAll(org.mockito.ArgumentMatchers.argThat(items -> {
      int count = 0;
      for (PracticePaperAudienceEntity ignored : items) count++;
      return count == 2;
    }));
  }

  @Test
  void rejectsSelectedStudentWithDifferentGrade() throws Exception {
    UUID familyId = UUID.randomUUID();
    PracticeGenerationRepository generations = mock(PracticeGenerationRepository.class);
    PracticePaperRepository papers = mock(PracticePaperRepository.class);
    PracticeQuestionRepository questions = mock(PracticeQuestionRepository.class);
    PracticePaperAudienceRepository audiences = mock(PracticePaperAudienceRepository.class);
    StudentService students = mock(StudentService.class);
    PracticeAudiencePolicy audiencePolicy = mock(PracticeAudiencePolicy.class);
    JsonMapper mapper = JsonMapper.builder().build();

    PracticeGenerationEntity generation = generation(familyId, mapper);
    when(generations.lockByIdAndFamilyId(generation.id, familyId)).thenReturn(Optional.of(generation));

    StudentEntity reference = student("ref", "小宇", "二年级", "上学期", "人教版数学二年级上册");
    StudentEntity older = student("older", "小华", "三年级", "上学期", "人教版数学三年级上册");
    when(students.requireOwned(familyId, "ref")).thenReturn(reference);
    when(students.requireOwned(familyId, "older")).thenReturn(older);
    when(audiencePolicy.gradeCode("二年级")).thenReturn("G2");
    when(audiencePolicy.gradeCode("三年级")).thenReturn("G3");
    when(audiencePolicy.semesterCode("上学期")).thenReturn("S1");

    PracticeGenerationService service = new PracticeGenerationService(
        generations, papers, questions, audiences, students, audiencePolicy,
        mock(PracticeGenerationModelClient.class),
        mock(PracticeGenerationReviewClient.class),
        mock(PracticeGeneratedContentValidator.class),
        mock(PracticeContentService.class),
        mapper);

    ApiExceptions.BadRequest error = assertThrows(ApiExceptions.BadRequest.class, () ->
        service.publish(
            familyId,
            generation.id,
            new PracticeGenerationDtos.PublishRequest("SELECTED", List.of("ref", "older"))));

    org.junit.jupiter.api.Assertions.assertTrue(error.getMessage().contains("小华"));
    verify(papers, never()).saveAndFlush(any(PracticePaperEntity.class));
  }

  private PracticeGenerationEntity generation(UUID familyId, JsonMapper mapper) throws Exception {
    PracticeGenerationEntity generation = new PracticeGenerationEntity();
    generation.id = UUID.randomUUID();
    generation.familyId = familyId;
    generation.referenceStudentId = "ref";
    generation.referenceTextbookContext = "人教版数学二年级上册";
    generation.subject = "MATH";
    generation.semester = "S1";
    generation.track = "TEXTBOOK_SYNC";
    generation.difficulty = "L1";
    generation.questionCount = 1;
    generation.requirement = "退位减法";
    generation.status = "READY";
    generation.paperId = "ai-test";
    generation.paperVersion = 1;
    generation.model = "test";
    generation.errorMessage = "";
    generation.createdAt = Instant.parse("2026-09-28T00:00:00Z");
    generation.updatedAt = generation.createdAt;
    PracticeContentCatalog.Question question = new PracticeContentCatalog.Question(
        "ai-test-Q01", 1, "NUMBER", "42-5等于多少？",
        List.of(), "37", "42减5等于37。",
        List.of("关键词：42、减5"), List.of("退位减法"));
    PracticeContentCatalog.Paper paper = new PracticeContentCatalog.Paper(
        "ai-test", 1, "G2", "MATH", "S1", "TEXTBOOK_SYNC",
        "退位减法专项", "测试", "L1", 1, 5, List.of("退位减法"),
        "AI_GENERATED", "PUBLISHED", List.of(question));
    generation.generatedJson = mapper.writeValueAsString(paper);
    return generation;
  }

  private StudentEntity student(
      String id, String name, String grade, String semester, String textbookSummary) {
    StudentEntity student = mock(StudentEntity.class);
    student.id = id;
    student.name = name;
    student.grade = grade;
    student.semester = semester;
    student.textbookSummary = textbookSummary;
    return student;
  }

  private PracticeDtos.PaperResponse paperResponse() {
    return new PracticeDtos.PaperResponse(
        "ai-test", 1, "G2", "MATH", "S1", "TEXTBOOK_SYNC",
        "退位减法专项", "测试", "L1", 1, 5,
        List.of("退位减法"), "AI_GENERATED");
  }
}
