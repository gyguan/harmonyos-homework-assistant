package com.xiaoban.homework.voicematerial;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentResourceService;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.student.StudentService;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

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
  void consumedPackageManualRetryNeverCreatesAnotherAssignment() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = new VoiceMaterialPackageEntity();
    item.id = packageId;
    item.familyId = familyId;
    item.studentId = "student-1";
    item.status = "CONSUMED";
    item.consumedAssignmentId = "a-voicepkg-" + packageId;

    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));

    VoiceMaterialDtos.CreateAssignmentResponse result =
        service().createManually(familyId, packageId);

    assertFalse(result.created());
    assertEquals(item.consumedAssignmentId, result.assignmentId());
    verify(assignments, never()).create(any(), anyString(), any());
  }
}
