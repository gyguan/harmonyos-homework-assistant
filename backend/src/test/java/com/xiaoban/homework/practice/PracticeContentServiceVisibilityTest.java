package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.common.ApiExceptions;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class PracticeContentServiceVisibilityTest {
  @Test
  void listsGlobalPresetAndOwnedGeneratedPaperOnly() {
    PracticePaperRepository papers = mock(PracticePaperRepository.class);
    PracticeContentService service = new PracticeContentService(
        papers, mock(PracticeQuestionRepository.class), JsonMapper.builder().build());

    UUID familyId = UUID.randomUUID();
    PracticePaperEntity preset = paper("preset-1", null, null, "PRESET");
    PracticePaperEntity owned = paper("ai-owned", familyId, "student-1", "AI_GENERATED");
    PracticePaperEntity otherStudent = paper("ai-other-student", familyId, "student-2", "AI_GENERATED");
    PracticePaperEntity otherFamily = paper("ai-other-family", UUID.randomUUID(), "student-1", "AI_GENERATED");
    when(papers.findAll()).thenReturn(List.of(preset, owned, otherStudent, otherFamily));

    List<PracticeDtos.PaperResponse> result = service.listForStudent(
        familyId, "student-1", "G2", "MATH", "S1", "TEXTBOOK_SYNC");

    assertEquals(List.of("ai-owned", "preset-1"), result.stream().map(PracticeDtos.PaperResponse::id).toList());
  }

  @Test
  void privatePaperCannotBeReadByAnotherStudent() {
    PracticePaperRepository papers = mock(PracticePaperRepository.class);
    PracticeContentService service = new PracticeContentService(
        papers, mock(PracticeQuestionRepository.class), JsonMapper.builder().build());

    UUID familyId = UUID.randomUUID();
    PracticePaperEntity owned = paper("ai-owned", familyId, "student-1", "AI_GENERATED");
    when(papers.findByPaperIdAndVersion("ai-owned", 1)).thenReturn(Optional.of(owned));

    assertThrows(ApiExceptions.NotFound.class, () ->
        service.requirePaperForStudent(familyId, "student-2", "ai-owned", 1));
  }

  private PracticePaperEntity paper(
      String paperId, UUID familyId, String studentId, String sourceType) {
    PracticePaperEntity paper = new PracticePaperEntity();
    paper.paperKey = paperId + "@1";
    paper.paperId = paperId;
    paper.version = 1;
    paper.familyId = familyId;
    paper.studentId = studentId;
    paper.grade = "G2";
    paper.subject = "MATH";
    paper.semester = "S1";
    paper.track = "TEXTBOOK_SYNC";
    paper.title = paperId;
    paper.description = "测试";
    paper.difficulty = "L1";
    paper.questionCount = 5;
    paper.estimatedMinutes = 10;
    paper.tagsJson = "[\"测试\"]";
    paper.sourceType = sourceType;
    paper.status = "PUBLISHED";
    paper.createdAt = Instant.parse("2026-09-28T00:00:00Z");
    paper.updatedAt = paper.createdAt;
    return paper;
  }
}
