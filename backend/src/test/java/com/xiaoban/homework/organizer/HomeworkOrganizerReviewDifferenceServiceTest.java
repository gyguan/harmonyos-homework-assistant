package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkOrganizerReviewDifferenceServiceTest {
  @Test
  void storesDetailedCorrectionsWithTeacherAndStudentScope() {
    UUID family = UUID.randomUUID();
    var teachers = mock(HomeworkStudentTeacherService.class);
    var repository = mock(HomeworkOrganizerReviewDifferenceRepository.class);
    when(teachers.verifiedTeacher(family, "student-1", "王老师")).thenReturn("王老师");
    when(repository.save(any(HomeworkOrganizerReviewDifferenceEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));
    var service = new HomeworkOrganizerReviewDifferenceService(repository, teachers);
    var differences = List.of(
        new HomeworkOrganizerReviewDifferenceService.Difference(
            "ai-1", "CHANGED", "subject", "数学", "语文", "读国13"),
        new HomeworkOrganizerReviewDifferenceService.Difference(
            "ai-2", "REMOVED", "task", "重复朗读", "", "读国13"),
        new HomeworkOrganizerReviewDifferenceService.Difference(
            "manual-1", "ADDED", "task", "", "朗读国学", "读国13"));
    var result = service.save(family, "student-1",
        new HomeworkOrganizerReviewDifferenceService.Review("batch-1", "王老师", differences));
    assertEquals(3, result.saved());
    var captor = org.mockito.ArgumentCaptor.forClass(HomeworkOrganizerReviewDifferenceEntity.class);
    verify(repository, times(3)).save(captor.capture());
    assertEquals("student-1", captor.getAllValues().getFirst().studentId);
    assertEquals("王老师", captor.getAllValues().getFirst().teacherName);
    assertEquals("subject", captor.getAllValues().getFirst().fieldName);
  }

  @Test
  void ignoresSameBatchCandidateFieldAndRejectsInvalidChange() {
    UUID family = UUID.randomUUID();
    var teachers = mock(HomeworkStudentTeacherService.class);
    var repository = mock(HomeworkOrganizerReviewDifferenceRepository.class);
    when(repository.existsByFamilyIdAndStudentIdAndBatchIdAndCandidateIdAndChangeTypeAndFieldName(
        family, "student-1", "batch-1", "ai-1", "CHANGED", "title")).thenReturn(true);
    var service = new HomeworkOrganizerReviewDifferenceService(repository, teachers);
    var duplicate = service.save(family, "student-1",
        new HomeworkOrganizerReviewDifferenceService.Review("batch-1", "",
            List.of(new HomeworkOrganizerReviewDifferenceService.Difference(
                "ai-1", "CHANGED", "title", "旧标题", "新标题", ""))));
    assertEquals(0, duplicate.saved());
    assertEquals(1, duplicate.ignored());
    verify(repository, never()).save(any());
    assertThrows(com.xiaoban.homework.common.ApiExceptions.BadRequest.class,
        () -> service.save(family, "student-1",
            new HomeworkOrganizerReviewDifferenceService.Review("batch-1", "",
                List.of(new HomeworkOrganizerReviewDifferenceService.Difference(
                    "ai-1", "CHANGED", "nonsense", "", "", "")))));
  }

  @Test
  void blocksAnotherStudentOrUnverifiedTeacherBeforeWritingAnything() {
    UUID family = UUID.randomUUID();
    var teachers = mock(HomeworkStudentTeacherService.class);
    var repository = mock(HomeworkOrganizerReviewDifferenceRepository.class);
    doThrow(new com.xiaoban.homework.common.ApiExceptions.NotFound("学生不存在"))
        .when(teachers).verifiedTeacher(family, "other-child", "王老师");
    var service = new HomeworkOrganizerReviewDifferenceService(repository, teachers);
    assertThrows(com.xiaoban.homework.common.ApiExceptions.NotFound.class,
        () -> service.save(family, "other-child",
            new HomeworkOrganizerReviewDifferenceService.Review("batch-1", "王老师",
                List.of(new HomeworkOrganizerReviewDifferenceService.Difference(
                    "ai-1", "REMOVED", "task", "误识别", "", "")))));
    verify(repository, never()).save(any());
  }
}
