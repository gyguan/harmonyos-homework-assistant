package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.storage.FileTransactionCoordinator;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.submission.SubmissionPhotoRepository;
import com.xiaoban.homework.submission.SubmissionRepository;
import com.xiaoban.homework.submission.SubmissionResourceRepository;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AssignmentServiceBusinessDateTest {
  @Test
  void activeVoiceTaskLookupUsesExactTaskDate() {
    AssignmentRepository repository = mock(AssignmentRepository.class);
    StudentService students = mock(StudentService.class);
    AssignmentService service = new AssignmentService(
        repository,
        students,
        mock(SubmissionRepository.class),
        mock(SubmissionPhotoRepository.class),
        mock(SubmissionResourceRepository.class),
        mock(AssignmentResourceRepository.class),
        mock(FileTransactionCoordinator.class));

    UUID familyId = UUID.randomUUID();
    LocalDate businessDate = LocalDate.of(2026, 9, 28);
    when(repository
        .findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotAndTaskDateOrderByUpdatedAtDesc(
            familyId, "student-1", "AUDIO_IMAGE", "COMPLETED", businessDate))
        .thenReturn(Optional.empty());

    assertNull(service.findFirstVoiceMaterialTaskForDate(
        familyId, "student-1", businessDate));

    verify(students).requireOwned(familyId, "student-1");
    verify(repository)
        .findFirstByFamilyIdAndStudentIdAndContentTypeAndStatusNotAndTaskDateOrderByUpdatedAtDesc(
            familyId, "student-1", "AUDIO_IMAGE", "COMPLETED", businessDate);
  }
}
