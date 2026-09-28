package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentService;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeGenerationServiceReviewTest {
  @Test
  void failedIndependentReviewNeverBecomesReady() {
    UUID familyId = UUID.randomUUID();
    StudentService students = mock(StudentService.class);
    PracticeAudiencePolicy audiencePolicy = mock(PracticeAudiencePolicy.class);
    PracticeGenerationRepository generations = mock(PracticeGenerationRepository.class);
    PracticeGenerationModelClient model = mock(PracticeGenerationModelClient.class);
    PracticeGenerationReviewClient reviewer = mock(PracticeGenerationReviewClient.class);

    StudentEntity student = mock(StudentEntity.class);
    student.id = "student-1";
    student.name = "小宇";
    student.grade = "二年级";
    student.semester = "上学期";
    student.textbookSummary = "人教版数学二年级上册";
    when(students.requireOwned(familyId, "student-1")).thenReturn(student);
    when(audiencePolicy.gradeCode("二年级")).thenReturn("G2");
    when(audiencePolicy.semesterCode("上学期")).thenReturn("S1");
    when(model.available()).thenReturn(true);
    when(model.model()).thenReturn("test-model");

    PracticeContentCatalog.Paper paper = paper();
    when(model.generate(
        eq("人教版数学二年级上册"),
        any(String.class),
        eq("G2"),
        eq("S1"),
        any(PracticeGenerationDtos.GenerateRequest.class)))
        .thenReturn(Optional.of(paper));
    when(reviewer.review(paper)).thenReturn(Optional.of(
        new PracticeGenerationReviewClient.ReviewResult(
            false,
            List.of(new PracticeGenerationReviewClient.ReviewIssue(
                "ai-test-Q01", "42减5的正确答案应为37")))));

    PracticeGenerationService service = new PracticeGenerationService(
        generations,
        mock(PracticePaperRepository.class),
        mock(PracticeQuestionRepository.class),
        mock(PracticePaperAudienceRepository.class),
        students,
        audiencePolicy,
        model,
        reviewer,
        mock(PracticeGeneratedContentValidator.class),
        mock(PracticeContentService.class),
        JsonMapper.builder().build());

    assertThrows(ApiExceptions.ServiceUnavailable.class, () ->
        service.generate(
            familyId,
            "student-1",
            new PracticeGenerationDtos.GenerateRequest(
                "MATH", "TEXTBOOK_SYNC", "L1", 5, "练习退位减法")));

    org.mockito.ArgumentCaptor<PracticeGenerationEntity> captor =
        org.mockito.ArgumentCaptor.forClass(PracticeGenerationEntity.class);
    org.mockito.Mockito.verify(generations, org.mockito.Mockito.atLeastOnce())
        .saveAndFlush(captor.capture());
    PracticeGenerationEntity last = captor.getAllValues().get(captor.getAllValues().size() - 1);
    assertEquals("FAILED", last.status);
  }

  private PracticeContentCatalog.Paper paper() {
    java.util.ArrayList<PracticeContentCatalog.Question> questions = new java.util.ArrayList<>();
    for (int i = 1; i <= 5; i++) {
      questions.add(new PracticeContentCatalog.Question(
          "ai-test-Q0" + i,
          i,
          "NUMBER",
          (40 + i) + " - 5 = ?",
          List.of(),
          Integer.toString(35 + i),
          "重新计算得到答案。",
          List.of("关键词：减5"),
          List.of("退位减法")));
    }
    return new PracticeContentCatalog.Paper(
        "ai-test", 1, "G2", "MATH", "S1", "TEXTBOOK_SYNC",
        "退位减法专项", "测试", "L1", 5, 10,
        List.of("退位减法"), "AI_GENERATED", "PUBLISHED", questions);
  }
}
