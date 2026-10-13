package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
import java.time.ZoneId;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AssignmentServiceBusinessDateTest {

  @Test
  void createDefaultsMissingTaskDateToBusinessToday() {
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
    when(repository.findById("a-default-date")).thenReturn(Optional.empty());
    when(repository.saveAndFlush(org.mockito.ArgumentMatchers.any(AssignmentEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));

    LocalDate expectedToday = LocalDate.now(ZoneId.of("Asia/Shanghai"));
    AssignmentDtos.Response created = service.create(
        familyId,
        "student-1",
        new AssignmentDtos.Create(
            "a-default-date",
            "语文",
            "当天任务",
            "完成当天任务",
            "",
            null,
            "SCHOOL",
            "CHINESE",
            "NORMAL",
            "NOT_STARTED",
            "",
            "",
            20,
            0L,
            0L,
            0L,
            ""));

    assertEquals(expectedToday.toString(), created.taskDate());
    verify(students).requireOwned(familyId, "student-1");
  }

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
