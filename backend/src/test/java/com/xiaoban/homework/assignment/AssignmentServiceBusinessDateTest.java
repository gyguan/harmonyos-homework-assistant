package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.storage.FileTransactionCoordinator;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.submission.SubmissionPhotoRepository;
import com.xiaoban.homework.submission.SubmissionRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AssignmentServiceBusinessDateTest {
  @Test
  void activeVoiceTaskLookupUsesShanghaiDueAtDayBoundary() {
    AssignmentRepository repository = mock(AssignmentRepository.class);
    StudentService students = mock(StudentService.class);
    AssignmentService service = new AssignmentService(
        repository,
        students,
        mock(SubmissionRepository.class),
        mock(SubmissionPhotoRepository.class),
        mock(AssignmentResourceRepository.class),
        mock(FileTransactionCoordinator.class));

    UUID familyId = UUID.randomUUID();
    LocalDate businessDate = LocalDate.of(2026, 9, 28);
    Instant expectedFrom = Instant.parse("2026-09-27T16:00:00Z");
    Instant expectedTo = Instant.parse("2026-09-28T16:00:00Z");

    when(repository
        .findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotAndDueAtGreaterThanEqualAndDueAtLessThanOrderByUpdatedAtDesc(
            familyId, "student-1", "AUDIO_IMAGE", "COMPLETED", expectedFrom, expectedTo))
        .thenReturn(Optional.empty());

    assertNull(service.findFirstVoiceMaterialTaskForDate(
        familyId, "student-1", businessDate));

    verify(students).requireOwned(familyId, "student-1");
    verify(repository)
        .findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotAndDueAtGreaterThanEqualAndDueAtLessThanOrderByUpdatedAtDesc(
            familyId, "student-1", "AUDIO_IMAGE", "COMPLETED", expectedFrom, expectedTo);
  }
}
