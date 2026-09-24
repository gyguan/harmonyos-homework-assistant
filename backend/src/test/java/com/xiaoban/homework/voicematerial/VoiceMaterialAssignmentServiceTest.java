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
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.function.Executable;
import org.mockito.ArgumentCaptor;

class VoiceMaterialAssignmentServiceTest {
  private final VoiceMaterialPackageRepository packages = mock(VoiceMaterialPackageRepository.class);
  private final VoiceMaterialFileRepository files = mock(VoiceMaterialFileRepository.class);
  private final VoiceMaterialTaskLinkRepository links = mock(VoiceMaterialTaskLinkRepository.class);
  private final VoiceMaterialAutoCreateRecordRepository autoRecords =
      mock(VoiceMaterialAutoCreateRecordRepository.class);
  private final AssignmentService assignments = mock(AssignmentService.class);
  private final AssignmentResourceService assignmentResources =
      mock(AssignmentResourceService.class);
  private final StudentService students = mock(StudentService.class);

  private VoiceMaterialAssignmentService service() {
    return new VoiceMaterialAssignmentService(
        packages, files, links, autoRecords, assignments, assignmentResources, students);
  }

  @Test
  void existingAutoRecordBlocksSameDayRecreationAfterAssignmentDeletion() {
    UUID familyId = UUID.randomUUID();
    UUID previousPackageId = UUID.randomUUID();

    VoiceMaterialAutoCreateRecordEntity record = new VoiceMaterialAutoCreateRecordEntity();
    record.id = UUID.randomUUID();
    record.familyId = familyId;
    record.studentId = "student-1";
    record.businessDate = LocalDate.now();
    record.packageId = previousPackageId;
    record.assignmentId = "a-voice-deleted";

    when(assignments.findFirstVoiceMaterialTask(familyId, "student-1")).thenReturn(null);
    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class)))
        .thenReturn(Optional.of(record));

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertFalse(result.created());
    assertEquals(previousPackageId.toString(), result.packageId());
    assertEquals(record.assignmentId, result.assignmentId());
    assertNull(result.assignment());
    verify(packages, never()).findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
        any(), anyString());
    verify(autoRecords, never()).saveAndFlush(any());
  }

  @Test
  void currentVoiceTaskBlocksAutomaticCreation() {
    UUID familyId = UUID.randomUUID();
    AssignmentDtos.Response current = response("a-voice-existing", "数学 · 语音作业");
    when(assignments.findFirstVoiceMaterialTask(familyId, "student-1")).thenReturn(current);
    VoiceMaterialTaskLinkEntity link = link(UUID.randomUUID(), current.id(), "student-1");
    when(links.findByFamilyIdAndAssignmentId(familyId, current.id()))
        .thenReturn(Optional.of(link));

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertFalse(result.created());
    assertEquals(current.id(), result.assignmentId());
    assertEquals(link.packageId.toString(), result.packageId());
    verify(packages, never()).findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
        any(), anyString());
  }

  @Test
  void automaticCreationUsesUnusedFolderAndKeepsItReady() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-语文", "READY");
    AssignmentDtos.Response created = response("a-voice-new", "语文 · 语音作业");

    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(Optional.empty());
    when(assignments.findFirstVoiceMaterialTask(familyId, "student-1")).thenReturn(null);
    when(packages.findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
        familyId, "student-1")).thenReturn(List.of(item));
    when(links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(
        familyId, "student-1")).thenReturn(List.of());
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
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
    assertEquals(created.id(), result.assignmentId());
    assertEquals("READY", item.status);
    verify(links).saveAndFlush(any(VoiceMaterialTaskLinkEntity.class));
  }

  @Test
  void manualCreationCanReusePreviouslyUsedReadyFolder() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-语文", "READY");
    AssignmentDtos.Response created = response("a-voice-second", "语文 · 第二次语音作业");

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());

    VoiceMaterialDtos.CreateAssignmentResponse result = service().createManually(
        familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            "student-1", "CHINESE", 18, 0L, "", "语文 · 第二次语音作业", "", "req-2"));

    assertTrue(result.created());
    assertEquals(created.id(), result.assignmentId());
    assertEquals("READY", item.status);
    ArgumentCaptor<VoiceMaterialTaskLinkEntity> link =
        ArgumentCaptor.forClass(VoiceMaterialTaskLinkEntity.class);
    verify(links).saveAndFlush(link.capture());
    assertEquals(packageId, link.getValue().packageId);
    assertEquals(created.id(), link.getValue().assignmentId);
    assertEquals("req-2", link.getValue().requestId);
  }

  @Test
  void activeVoiceTaskDoesNotBlockManualCreation() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "002-数学", "READY");
    AssignmentDtos.Response active = response("a-voice-existing", "语文 · 已有语音作业");
    AssignmentDtos.Response created = response("a-voice-manual-new", "数学 · 手工语音作业");

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(assignments.findFirstVoiceMaterialTask(familyId, "student-1")).thenReturn(active);
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());

    VoiceMaterialDtos.CreateAssignmentResponse result = service().createManually(
        familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            "student-1", "MATH", 15, 0L, "", "数学 · 手工语音作业", "", "req-parallel"));

    assertTrue(result.created());
    assertEquals(created.id(), result.assignmentId());
    verify(assignments, never()).findFirstVoiceMaterialTask(familyId, "student-1");
  }

  @Test
  void sameManualRequestIdReturnsExistingAssignment() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-语文", "READY");
    VoiceMaterialTaskLinkEntity link = link(packageId, "a-voice-existing", "student-1");
    link.requestId = "req-1";
    AssignmentDtos.Response existing = response(link.assignmentId, "语文 · 语音作业");

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(links.findByFamilyIdAndRequestId(familyId, "req-1")).thenReturn(Optional.of(link));
    when(assignments.get(familyId, link.assignmentId)).thenReturn(existing);

    VoiceMaterialDtos.CreateAssignmentResponse result = service().createManually(
        familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            "student-1", null, 15, 0L, "", "", "", "req-1"));

    assertFalse(result.created());
    assertEquals(existing.id(), result.assignmentId());
    assertEquals(existing.id(), result.assignment().id());
    verify(assignments, never()).create(any(), anyString(), any());
  }

  @Test
  void manualCreationUsesTitleDueDateAndExpectedMinutes() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-课文朗读", "READY");
    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());
    AssignmentDtos.Response authoritative = response("a-voice-new", "自定义语音作业");
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(authoritative);

    long dueAt = Instant.parse("2026-09-25T15:59:59Z").toEpochMilli();
    VoiceMaterialDtos.CreateAssignmentResponse result = service().createManually(
        familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            "student-1", "ENGLISH", 30, dueAt, "自定义", "自定义语音作业", "先听两遍并跟读。", "req-custom"));

    ArgumentCaptor<AssignmentDtos.Create> input =
        ArgumentCaptor.forClass(AssignmentDtos.Create.class);
    verify(assignments).create(any(UUID.class), org.mockito.ArgumentMatchers.eq("student-1"), input.capture());
    assertEquals(30, input.getValue().expectedMinutes());
    assertEquals(dueAt, input.getValue().dueAtEpochMs());
    assertEquals("ENGLISH", input.getValue().subjectCode());
    assertEquals("英语", input.getValue().subject());
    assertEquals("自定义语音作业", input.getValue().title());
    assertEquals("先听两遍并跟读。", input.getValue().instruction());
    assertTrue(result.created());
  }

  @Test
  void folderCannotBeUsedForDifferentStudent() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));

    Executable action = () -> service().createManually(
        familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            "student-2", null, 15, 0L, "", "", "", "req-cross"));

    org.junit.jupiter.api.Assertions.assertThrows(ApiExceptions.BadRequest.class, action);
    verify(packages, never()).lockOwned(any(), any());
  }

  private VoiceMaterialPackageEntity packageEntity(
      UUID familyId, UUID id, String directoryName, String status) {
    VoiceMaterialPackageEntity item = new VoiceMaterialPackageEntity();
    item.id = id;
    item.familyId = familyId;
    item.studentId = "student-1";
    item.directoryName = directoryName;
    item.subjectCode = "CHINESE";
    item.title = "课文朗读";
    item.assignmentType = "EXTRA";
    item.expectedMinutes = 15;
    item.status = status;
    item.dueAt = null;
    item.createdAt = Instant.now();
    return item;
  }

  private VoiceMaterialTaskLinkEntity link(UUID packageId, String assignmentId, String studentId) {
    VoiceMaterialTaskLinkEntity link = new VoiceMaterialTaskLinkEntity();
    link.id = UUID.randomUUID().toString();
    link.packageId = packageId;
    link.assignmentId = assignmentId;
    link.studentId = studentId;
    link.createdAt = Instant.now();
    return link;
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
