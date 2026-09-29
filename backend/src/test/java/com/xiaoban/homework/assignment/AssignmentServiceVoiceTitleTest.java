package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.storage.FileTransactionCoordinator;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.submission.SubmissionPhotoRepository;
import com.xiaoban.homework.submission.SubmissionRepository;
import java.time.Instant;
import java.time.LocalDate;
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
}
