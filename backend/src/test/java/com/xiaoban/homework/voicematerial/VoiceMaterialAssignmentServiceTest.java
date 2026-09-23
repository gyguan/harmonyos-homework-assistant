package com.xiaoban.homework.voicematerial;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentResourceService;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
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
  private final AssignmentResourceService assignmentResources =
      mock(AssignmentResourceService.class);
  private final StudentService students = mock(StudentService.class);

  private VoiceMaterialAssignmentService service() {
    return new VoiceMaterialAssignmentService(
        packages, files, autoRecords, assignments, assignmentResources, students);
  }

  @Test
  void existingAutoCreateRecordDoesNotBlockRecreationAfterAssignmentDeletion() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialAutoCreateRecordEntity existingRecord = new VoiceMaterialAutoCreateRecordEntity();
    existingRecord.id = UUID.randomUUID();
    existingRecord.familyId = familyId;
    existingRecord.studentId = "student-1";
    existingRecord.businessDate = LocalDate.now();
    existingRecord.packageId = packageId;
    existingRecord.assignmentId = "a-voicepkg-" + packageId;

    VoiceMaterialPackageEntity item = packageEntity(packageId, "001-语文", "CONSUMED");
    item.consumedAssignmentId = existingRecord.assignmentId;

    AssignmentDtos.Response created = response(existingRecord.assignmentId, "语文 · 语音作业");
    when(assignments.findFirstVoiceMaterialTask(familyId, "student-1")).thenReturn(null);
    when(packages.lockNextAvailableForAutoCreate(
        any(UUID.class), anyString(), any())).thenReturn(List.of(item));
    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class)))
        .thenReturn(Optional.of(existingRecord));
    when(assignments.nextVoiceMaterialTaskTitle(
        any(UUID.class), anyString(), anyString(), any(LocalDate.class)))
        .thenReturn("语文 · 语音作业");
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertTrue(result.created());
    assertEquals(packageId.toString(), result.packageId());
    assertEquals(existingRecord.assignmentId, result.assignmentId());
    verify(packages).lockNextAvailableForAutoCreate(
        familyId, "student-1", org.mockito.ArgumentMatchers.any());
  }

  @Test
  void currentManualVoiceTaskBlocksAutomaticCreation() {
    UUID familyId = UUID.randomUUID();
    AssignmentDtos.Response current = response("a-voicepkg-existing", "数学 · 语音作业");
    when(assignments.findFirstVoiceMaterialTask(familyId, "student-1")).thenReturn(current);

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertFalse(result.created());
    assertEquals(current.id(), result.assignmentId());
    assertEquals(current.id(), result.assignment().id());
    verify(packages, never()).lockNextAvailableForAutoCreate(
        any(UUID.class), anyString(), any());
  }

  @Test
  void automaticCreationUsesFirstPackageWithoutCurrentAssignmentAssociation() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(packageId, "001-语文", "READY");
    AssignmentDtos.Response created = response("a-voicepkg-" + packageId, "语文 · 语音作业");

    when(assignments.findFirstVoiceMaterialTask(familyId, "student-1")).thenReturn(null);
    when(packages.lockNextAvailableForAutoCreate(
        any(UUID.class), anyString(), any())).thenReturn(List.of(item));
    when(assignments.nextVoiceMaterialTaskTitle(
        any(UUID.class), anyString(), anyString(), any(LocalDate.class)))
        .thenReturn("语文 · 语音作业");
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());
    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(Optional.empty());

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertTrue(result.created());
    assertEquals(packageId.toString(), result.packageId());
    assertEquals(created.id(), result.assignmentId());
    assertEquals("CONSUMED", item.status);
  }

  @Test
  void manuallyReusesConsumedPackageWhenPreviousAssignmentWasDeleted() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(packageId, "001-语文", "CONSUMED");
    item.consumedAssignmentId = "a-voicepkg-" + packageId;

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(assignments.get(familyId, item.consumedAssignmentId))
        .thenThrow(new com.xiaoban.homework.common.ApiExceptions.NotFound("作业不存在"));
    when(assignments.nextVoiceMaterialTaskTitle(
        any(UUID.class), anyString(), anyString(), any(LocalDate.class)))
        .thenReturn("语文 · 语音作业");
    AssignmentDtos.Response created = response(item.consumedAssignmentId, "语文 · 语音作业");
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());

    VoiceMaterialDtos.CreateAssignmentResponse result =
        service().createManually(familyId, packageId);

    assertTrue(result.created());
    assertEquals(created.id(), result.assignmentId());
    assertEquals("CONSUMED", item.status);
  }

  @Test
  void manuallyCreatingOnActivePackageReturnsExistingAssignment() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(packageId, "001-语文", "CONSUMED");
    item.consumedAssignmentId = "a-voicepkg-" + packageId;
    AssignmentDtos.Response existing = response(item.consumedAssignmentId, "语文 · 语音作业");

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(assignments.get(familyId, item.consumedAssignmentId)).thenReturn(existing);

    VoiceMaterialDtos.CreateAssignmentResponse result =
        service().createManually(familyId, packageId);

    assertFalse(result.created());
    assertEquals(existing.id(), result.assignmentId());
    assertEquals(existing.id(), result.assignment().id());
    verify(assignments, never()).create(any(), anyString(), any());
  }

  @Test
  void manualCreationUsesSelectedStudentDueDateAndExpectedMinutes() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(packageId, "001-课文朗读", "READY");
    item.expectedMinutes = 15;
    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());
    when(assignments.nextVoiceMaterialTaskTitle(
        any(UUID.class), anyString(), anyString(), any(LocalDate.class)))
        .thenReturn("语文 · 语音作业");
    AssignmentDtos.Response authoritative = response("a-voicepkg-" + packageId, "语文 · 语音作业");
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(authoritative);

    long dueAt = Instant.parse("2026-09-25T15:59:59Z").toEpochMilli();
    VoiceMaterialDtos.CreateAssignmentResponse result = service().createManually(
        familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest("student-2", 30, dueAt, "自定义"));

    ArgumentCaptor<AssignmentDtos.Create> input =
        ArgumentCaptor.forClass(AssignmentDtos.Create.class);
    verify(assignments).create(any(UUID.class), org.mockito.ArgumentMatchers.eq("student-2"), input.capture());
    assertEquals(30, input.getValue().expectedMinutes());
    assertEquals(dueAt, input.getValue().dueAtEpochMs());
    assertTrue(result.created());
  }

  @Test
  void readyManualPackageWithoutDueAtKeepsAssignmentDueAtNullable() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(packageId, "001-课文朗读", "READY");
    item.subjectCode = "CHINESE";
    item.title = "课文朗读";
    item.assignmentType = "EXTRA";
    item.expectedMinutes = 15;
    item.dueAt = null;

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());
    when(assignments.nextVoiceMaterialTaskTitle(
        any(UUID.class), anyString(), anyString(), any(LocalDate.class)))
        .thenReturn("语文 · 语音作业");

    AssignmentDtos.Response authoritative = response("a-voicepkg-" + packageId, "语文 · 语音作业");
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

  private VoiceMaterialPackageEntity packageEntity(UUID id, String directoryName, String status) {
    VoiceMaterialPackageEntity item = new VoiceMaterialPackageEntity();
    item.id = id;
    item.familyId = UUID.randomUUID();
    item.studentId = "student-1";
    item.directoryName = directoryName;
    item.subjectCode = "CHINESE";
    item.title = "课文朗读";
    item.assignmentType = "EXTRA";
    item.expectedMinutes = 15;
    item.status = status;
    item.dueAt = null;
    return item;
  }

  private AssignmentDtos.Response response(String id, String title) {
    return new AssignmentDtos.Response(
        id, "student-1", "EXTRA", "CHINESE",
        "AUDIO_IMAGE", "语文", title, "请听语音并结合图片完成任务。",
        "", 0L, "Asia/Shanghai", "", "NOT_STARTED",
        "语音素材库", "001-课文朗读", 15,
        0L, 0L, 0L, "", 0L);
  }
}
