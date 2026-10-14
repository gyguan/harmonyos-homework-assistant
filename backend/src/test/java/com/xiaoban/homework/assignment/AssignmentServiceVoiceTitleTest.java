package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.storage.FileTransactionCoordinator;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.submission.SubmissionPhotoRepository;
import com.xiaoban.homework.submission.SubmissionRepository;
import com.xiaoban.homework.submission.SubmissionResourceRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AssignmentServiceVoiceTitleTest {
  private final AssignmentRepository repository = mock(AssignmentRepository.class);
  private final StudentService students = mock(StudentService.class);
  private final AssignmentService service = new AssignmentService(
      repository,
      students,
      mock(SubmissionRepository.class),
      mock(SubmissionPhotoRepository.class),
      mock(SubmissionResourceRepository.class),
      mock(AssignmentResourceRepository.class),
      mock(FileTransactionCoordinator.class));

  @Test
  void generatedVoiceTitleUsesBusinessDateAndMaterialTitle() {
    UUID familyId = UUID.randomUUID();
    LocalDate businessDate = LocalDate.of(2026, 9, 28);
    Instant from = Instant.parse("2026-09-27T16:00:00Z");
    Instant to = Instant.parse("2026-09-28T16:00:00Z");
    String base = "语文 · 9月28日 · 课文朗读";

    when(repository
        .countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            familyId, "student-1", "CHINESE", "AUDIO_IMAGE", base, from, to))
        .thenReturn(0L);

    String title = service.nextVoiceMaterialTaskTitle(
        familyId, "student-1", "CHINESE", businessDate, "课文朗读");

    assertEquals(base, title);
    verify(repository)
        .countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            familyId, "student-1", "CHINESE", "AUDIO_IMAGE", base, from, to);
  }

  @Test
  void duplicateGeneratedVoiceTitleAddsSequenceWithoutUsingFolderName() {
    UUID familyId = UUID.randomUUID();
    LocalDate businessDate = LocalDate.of(2026, 9, 28);
    Instant from = Instant.parse("2026-09-27T16:00:00Z");
    Instant to = Instant.parse("2026-09-28T16:00:00Z");
    String base = "数学 · 9月28日语音作业";

    when(repository
        .countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            familyId, "student-1", "MATH", "AUDIO_IMAGE", base, from, to))
        .thenReturn(1L);

    String title = service.nextVoiceMaterialTaskTitle(
        familyId, "student-1", "MATH", businessDate, "");

    assertEquals("数学 · 9月28日语音作业 ②", title);
  }

  @Test
  void carryOverMovesTaskToBusinessDateAndRefreshesDatedTitle() {
    UUID familyId = UUID.randomUUID();
    LocalDate taskDate = LocalDate.of(2026, 9, 27);
    LocalDate businessDate = LocalDate.of(2026, 9, 28);
    String base = "语文 · 9月28日 · 课文朗读";
    AssignmentEntity entity = voiceTask("a-voice-1", familyId, "PAUSED", taskDate);

    when(repository.findById("a-voice-1")).thenReturn(Optional.of(entity));
    when(repository.saveAndFlush(entity)).thenReturn(entity);
    // 这条任务自己就落在当天的同名计数窗口里；如果把它数进去，名称会被错误地追加成「… ②」。
    when(repository
        .countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            familyId, "student-1", "CHINESE", "AUDIO_IMAGE", base,
            Instant.parse("2026-09-27T16:00:00Z"), Instant.parse("2026-09-28T16:00:00Z")))
        .thenReturn(1L);
    when(repository
        .countByFamilyIdAndStudentIdAndSubjectCodeAndContentTypeAndTitleStartingWithAndCreatedAtGreaterThanEqualAndCreatedAtLessThanAndIdNot(
            familyId, "student-1", "CHINESE", "AUDIO_IMAGE", base,
            Instant.parse("2026-09-27T16:00:00Z"), Instant.parse("2026-09-28T16:00:00Z"),
            "a-voice-1"))
        .thenReturn(0L);

    AssignmentDtos.Response result =
        service.carryOverToBusinessDate(familyId, "a-voice-1", businessDate, "课文朗读");

    assertEquals(businessDate, entity.taskDate);
    assertEquals(base, entity.title);
    // 顺延只挪日期与名称：作答进度必须原样保留，孩子做到一半的任务不能被重置。
    assertEquals("PAUSED", entity.status);
    assertEquals(businessDate.toString(), result.taskDate());
    assertEquals(base, result.title());
  }

  @Test
  void carryOverIsIdempotentWhenTargetDateIsNotLater() {
    UUID familyId = UUID.randomUUID();
    LocalDate taskDate = LocalDate.of(2026, 9, 28);
    AssignmentEntity entity = voiceTask("a-voice-1", familyId, "NOT_STARTED", taskDate);
    when(repository.findById("a-voice-1")).thenReturn(Optional.of(entity));

    AssignmentDtos.Response result = service.carryOverToBusinessDate(
        familyId, "a-voice-1", taskDate, "课文朗读");

    assertEquals(taskDate.toString(), result.taskDate());
    verify(repository, never()).saveAndFlush(any(AssignmentEntity.class));
  }

  private AssignmentEntity voiceTask(
      String id, UUID familyId, String status, LocalDate taskDate) {
    AssignmentEntity entity = new AssignmentEntity();
    entity.id = id;
    entity.familyId = familyId;
    entity.studentId = "student-1";
    entity.contentType = "AUDIO_IMAGE";
    entity.subjectCode = "CHINESE";
    entity.title = "语文 · 9月27日 · 课文朗读";
    entity.status = status;
    entity.taskDate = taskDate;
    entity.createdAt = Instant.now();
    entity.updatedAt = Instant.now();
    return entity;
  }
}
