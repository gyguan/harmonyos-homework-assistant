package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentRepository;
import com.xiaoban.homework.common.ApiExceptions;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class HomeworkOrganizerFinalizationTest {
  private static HomeworkOrganizerAiSnapshotEntity original(UUID family, String student, String batch,
      String candidateId, String title) {
    var e = new HomeworkOrganizerAiSnapshotEntity();
    e.id = UUID.randomUUID();
    e.familyId = family;
    e.studentId = student;
    e.batchId = batch;
    e.candidateId = candidateId;
    e.teacherName = "";
    e.subject = "语文";
    e.title = title;
    e.instruction = "读课文";
    e.textbookRef = "课本";
    e.taskDate = "2026-10-19";
    e.expectedMinutes = 20;
    e.sourceExcerpt = "老师：国13";
    return e;
  }

  private static AssignmentEntity published(UUID family, String student, String id, String title) {
    var e = new AssignmentEntity();
    e.id = "a-published-" + id;
    e.familyId = family;
    e.studentId = student;
    e.title = title;
    e.subject = "语文";
    e.instruction = "读课文";
    e.textbookRef = "课本";
    e.taskDate = LocalDate.of(2026, 10, 19);
    e.expectedMinutes = 20;
    e.sourceExcerpt = "老师：国13";
    return e;
  }

  @Test
  void comparesRealPublishedRowsInsteadOfClientClaimsAndTracksAddedRemoved() {
    UUID family = UUID.randomUUID();
    String student = "child1";
    String batch = "text-100";
    var teachers = mock(HomeworkStudentTeacherService.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var assignments = mock(AssignmentRepository.class);
    var differences = mock(HomeworkOrganizerReviewDifferenceRepository.class);
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, student, batch)).thenReturn(List.of(
            original(family, student, batch, "ai-text-100-1", "国13"),
            original(family, student, batch, "ai-text-100-2", "多生成了作业")));
    when(assignments.findById("a-published-ai-text-100-1")).thenReturn(Optional.of(
        published(family, student, "ai-text-100-1", "朗读国学13页")));
    when(assignments.findById("a-published-manual-9")).thenReturn(Optional.of(
        published(family, student, "manual-9", "补充听写")));
    when(differences.save(any(HomeworkOrganizerReviewDifferenceEntity.class)))
        .thenAnswer(i -> i.getArgument(0));
    var service = new HomeworkOrganizerReviewDifferenceService(
        differences, teachers, snapshots, assignments);
    var result = service.finalizePublished(family, student,
        new HomeworkOrganizerReviewDifferenceService.Finalize(batch,
            List.of("ai-text-100-1", "manual-9")));
    assertEquals(3, result.saved());
    var captor = ArgumentCaptor.forClass(HomeworkOrganizerReviewDifferenceEntity.class);
    verify(differences, times(3)).save(captor.capture());
    assertTrue(captor.getAllValues().stream().anyMatch(x ->
        x.fieldName.equals("title") && x.beforeValue.equals("国13") && x.afterValue.equals("朗读国学13页")));
    assertTrue(captor.getAllValues().stream().anyMatch(x ->
        x.changeType.equals("REMOVED") && x.candidateId.equals("ai-text-100-2")));
    assertTrue(captor.getAllValues().stream().anyMatch(x ->
        x.changeType.equals("ADDED") && x.candidateId.equals("manual-9")));
  }

  @Test
  void skipsLegacyBatchWithNoSnapshotInsteadOfFabricatingCorrections() {
    UUID family = UUID.randomUUID();
    var teachers = mock(HomeworkStudentTeacherService.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var assignments = mock(AssignmentRepository.class);
    var differences = mock(HomeworkOrganizerReviewDifferenceRepository.class);
    var service = new HomeworkOrganizerReviewDifferenceService(
        differences, teachers, snapshots, assignments);
    var result = service.finalizePublished(family, "s1",
        new HomeworkOrganizerReviewDifferenceService.Finalize("old-batch", List.of("ai-old-1")));
    assertEquals(0, result.saved());
    verifyNoInteractions(assignments, differences);
  }

  @Test
  void refusesCrossFamilyPublishedAssignmentAndUnknownCandidate() {
    UUID family = UUID.randomUUID();
    var teachers = mock(HomeworkStudentTeacherService.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var assignments = mock(AssignmentRepository.class);
    var differences = mock(HomeworkOrganizerReviewDifferenceRepository.class);
    when(snapshots.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, "s1", "batch-1")).thenReturn(List.of(original(family, "s1", "batch-1",
          "ai-batch-1-1", "原题")));
    when(assignments.findById("a-published-ai-batch-1-1")).thenReturn(Optional.of(
        published(UUID.randomUUID(), "s1", "ai-batch-1-1", "假冒任务")));
    var service = new HomeworkOrganizerReviewDifferenceService(
        differences, teachers, snapshots, assignments);
    assertThrows(ApiExceptions.NotFound.class,
        () -> service.finalizePublished(family, "s1",
            new HomeworkOrganizerReviewDifferenceService.Finalize(
                "batch-1", List.of("ai-batch-1-1"))));
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.finalizePublished(family, "s1",
            new HomeworkOrganizerReviewDifferenceService.Finalize(
                "batch-1", List.of("another-batch-task"))));
    verifyNoInteractions(differences);
  }
}
