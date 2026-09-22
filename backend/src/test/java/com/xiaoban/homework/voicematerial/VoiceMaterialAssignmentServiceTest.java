package com.xiaoban.homework.voicematerial;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import java.time.Instant;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentResourceService;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.student.StudentService;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class VoiceMaterialAssignmentServiceTest {
  private final VoiceMaterialPackageRepository packages = mock(VoiceMaterialPackageRepository.class);
  private final VoiceMaterialFileRepository files = mock(VoiceMaterialFileRepository.class);
  private final VoiceMaterialAutoCreateRecordRepository autoRecords =
      mock(VoiceMaterialAutoCreateRecordRepository.class);
  private final AssignmentService assignments = mock(AssignmentService.class);
  private final AssignmentResourceService assignmentResources = mock(AssignmentResourceService.class);
  private final StudentService students = mock(StudentService.class);

  private VoiceMaterialAssignmentService service() {
    return new VoiceMaterialAssignmentService(
        packages, files, autoRecords, assignments, assignmentResources, students);
  }

  @Test
  void secondAutomaticCheckOnSameBusinessDayDoesNotConsumeAnotherPackage() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialAutoCreateRecordEntity existing = new VoiceMaterialAutoCreateRecordEntity();
    existing.id = UUID.randomUUID();
    existing.familyId = familyId;
    existing.studentId = "student-1";
    existing.businessDate = LocalDate.now();
    existing.packageId = packageId;
    existing.assignmentId = "a-voicepkg-" + packageId;

    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class)))
        .thenReturn(Optional.of(existing));

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertFalse(result.created());
    assertEquals(existing.assignmentId, result.assignmentId());
    verify(packages, never()).lockNextReady(any(UUID.class), anyString(), any());
  }


  @Test
  void readyManualPackageWithoutDueAtKeepsAssignmentDueAtNullable() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = new VoiceMaterialPackageEntity();
    item.id = packageId;
    item.familyId = familyId;
    item.studentId = "student-1";
    item.status = "READY";
    item.subjectCode = "CHINESE";
    item.title = "课文朗读";
    item.assignmentType = "EXTRA";
    item.expectedMinutes = 15;
    item.directoryName = "001-课文朗读";
    item.dueAt = null;

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(java.util.List.of());
    when(assignments.nextVoiceMaterialTaskTitle(
        any(UUID.class), anyString(), anyString(), any(LocalDate.class)))
        .thenReturn("语文 · 语音作业");

    AssignmentDtos.Response authoritative = new AssignmentDtos.Response(
        "a-voicepkg-" + packageId, "student-1", "EXTRA", "CHINESE",
        "AUDIO_IMAGE", "语文", "课文朗读", "请听语音并结合图片完成任务。",
        "", 0L, "Asia/Shanghai", "", "NOT_STARTED",
        "语音素材库", "001-课文朗读", 15,
        0L, 0L, 0L, "", 0L);
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(authoritative);

    VoiceMaterialDtos.CreateAssignmentResponse result =
        service().createManually(familyId, packageId);

    ArgumentCaptor<AssignmentDtos.Create> input =
        ArgumentCaptor.forClass(AssignmentDtos.Create.class);
    verify(assignments).create(any(UUID.class), anyString(), input.capture());
    assertNull(input.getValue().dueAtEpochMs());
    assertEquals("语文 · 语音作业", input.getValue().title());
    assertTrue(result.created());
    assertEquals("CONSUMED", item.status);
    verify(students).requireOwnedForUpdate(familyId, "student-1");
  }

  @Test
  void consumedPackageManualRetryNeverCreatesAnotherAssignment() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = new VoiceMaterialPackageEntity();
    item.id = packageId;
    item.familyId = familyId;
    item.studentId = "student-1";
    item.status = "CONSUMED";
    item.consumedAssignmentId = "a-voicepkg-" + packageId;

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));

    VoiceMaterialDtos.CreateAssignmentResponse result =
        service().createManually(familyId, packageId);

    assertFalse(result.created());
    assertEquals(item.consumedAssignmentId, result.assignmentId());
    verify(students).requireOwnedForUpdate(familyId, "student-1");
    verify(assignments, never()).create(any(), anyString(), any());
  }
}
