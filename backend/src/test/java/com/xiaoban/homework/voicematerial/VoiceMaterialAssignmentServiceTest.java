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
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentDtos;
import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.assignment.AssignmentRepository;
import com.xiaoban.homework.assignment.AssignmentResourceService;
import com.xiaoban.homework.assignment.AssignmentService;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentService;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
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
  private final AssignmentRepository assignmentRepository = mock(AssignmentRepository.class);
  private final AssignmentService assignments = mock(AssignmentService.class);
  private final AssignmentResourceService assignmentResources =
      mock(AssignmentResourceService.class);
  private final StudentService students = mock(StudentService.class);

  private VoiceMaterialAssignmentService service() {
    return new VoiceMaterialAssignmentService(
        packages, files, links, autoRecords, assignmentRepository, assignments,
        assignmentResources, students);
  }

  /** AssignmentEntity 的构造器是 protected，测试用 Mockito 造实例（字段都是 public）。 */
  private AssignmentEntity voiceAssignment(String id, UUID familyId, String status) {
    AssignmentEntity entity = mock(AssignmentEntity.class);
    entity.id = id;
    entity.familyId = familyId;
    entity.studentId = "student-1";
    entity.contentType = "AUDIO_IMAGE";
    entity.title = "语文 · 语音作业";
    entity.status = status;
    return entity;
  }

  @Test
  void batchDeleteTasksAllowsCompletedAndSkipsUnknownIds() {
    UUID familyId = UUID.randomUUID();
    AssignmentEntity active = voiceAssignment("a-voice-active", familyId, "NOT_STARTED");
    AssignmentEntity completed = voiceAssignment("a-voice-done", familyId, "COMPLETED");
    when(assignmentRepository.findById("a-voice-active")).thenReturn(Optional.of(active));
    when(assignmentRepository.findById("a-voice-done")).thenReturn(Optional.of(completed));
    when(assignmentRepository.findById("missing")).thenReturn(Optional.empty());

    VoiceMaterialDtos.BatchDeleteResponse result = service().batchDeleteTasks(
        familyId, List.of("a-voice-active", "a-voice-done", "missing"));

    assertEquals(3, result.requested());
    assertEquals(2, result.deleted());
    assertEquals(1, result.skipped());
    assertEquals("语音任务不存在或无权访问", result.items().get(2).reason());
    // 「已完成」任务单条 DELETE 会被拒绝，批量入口必须显式放行。
    verify(assignments).deleteAllowingCompleted(familyId, "a-voice-active");
    verify(assignments).deleteAllowingCompleted(familyId, "a-voice-done");
    // 与单条删除保持一致：保留 task_link 与自动建任务记录，文件夹使用历史与每日限额不受影响。
    verifyNoInteractions(links, autoRecords);
  }

  @Test
  void batchDeleteTasksSkipsNonVoiceAndForeignAssignments() {
    UUID familyId = UUID.randomUUID();
    AssignmentEntity ordinary = voiceAssignment("a-normal", familyId, "NOT_STARTED");
    ordinary.contentType = "NORMAL";
    AssignmentEntity foreign = voiceAssignment("a-foreign", UUID.randomUUID(), "NOT_STARTED");
    when(assignmentRepository.findById("a-normal")).thenReturn(Optional.of(ordinary));
    when(assignmentRepository.findById("a-foreign")).thenReturn(Optional.of(foreign));

    VoiceMaterialDtos.BatchDeleteResponse result = service().batchDeleteTasks(
        familyId, List.of("a-normal", "a-foreign"));

    assertEquals(0, result.deleted());
    assertEquals(2, result.skipped());
    assertEquals("不是语音任务，已跳过", result.items().get(0).reason());
    assertEquals("语音任务不存在或无权访问", result.items().get(1).reason());
    verify(assignments, never()).deleteAllowingCompleted(any(), anyString());
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

    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(null);
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
  void currentBusinessDayVoiceTaskBlocksAutomaticCreation() {
    UUID familyId = UUID.randomUUID();
    AssignmentDtos.Response current = response("a-voice-existing", "数学 · 语音作业");
    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(current);
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
  void automaticCreationProceedsWhenNoAutoTaskNeedsCarryOver() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-语文", "READY");
    AssignmentDtos.Response created = response("a-voice-new", "语文 · 语音作业");

    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(Optional.empty());
    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(null);
    when(packages.findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
        familyId, "student-1")).thenReturn(List.of(item));
    when(links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(
        familyId, "student-1")).thenReturn(List.of());
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(assignments.nextVoiceMaterialTaskTitle(
        any(UUID.class), anyString(), anyString(), any(LocalDate.class), anyString()))
        .thenReturn("语文 · 9月28日 · 课文朗读");
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertTrue(result.created());
    assertFalse(result.carriedOver());
    assertEquals(packageId.toString(), result.packageId());
    assertEquals(created.id(), result.assignmentId());
    assertEquals("READY", item.status);
    verify(links).saveAndFlush(any(VoiceMaterialTaskLinkEntity.class));
  }

  @Test
  void unfinishedAutoTaskFromPreviousDayIsCarriedOverInsteadOfCreatingAnother() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    LocalDate today = LocalDate.now(ZoneId.of("Asia/Shanghai"));
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-语文", "READY");

    AssignmentEntity previous = voiceAssignment("a-voice-yesterday", familyId, "PAUSED");
    previous.taskDate = today.minusDays(1);
    VoiceMaterialTaskLinkEntity link = link(packageId, previous.id, "student-1");
    link.createMode = "AUTO";
    AssignmentDtos.Response moved = response(previous.id, "语文 · 语音作业");

    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(null);
    when(links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, "student-1"))
        .thenReturn(List.of(link));
    when(assignmentRepository.findById(previous.id)).thenReturn(Optional.of(previous));
    when(packages.findById(packageId)).thenReturn(Optional.of(item));
    when(assignments.carryOverToBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class), anyString())).thenReturn(moved);

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertFalse(result.created());
    assertTrue(result.carriedOver());
    assertEquals(previous.id, result.assignmentId());
    assertEquals(packageId.toString(), result.packageId());
    assertEquals(moved, result.assignment());
    // 名称必须按今天的业务日重算，素材标题取自原目录。
    verify(assignments).carryOverToBusinessDate(familyId, previous.id, today, item.title);
    // 顺延不是「再发一份」：既不能新建任务，也不能重新走一遍选目录。
    verify(assignments, never()).create(any(), anyString(), any());
    verify(packages, never()).findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
        any(), anyString());
  }

  @Test
  void carryOverConsumesTodaysAutoCreateQuota() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    LocalDate today = LocalDate.now(ZoneId.of("Asia/Shanghai"));
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-语文", "READY");

    AssignmentEntity previous = voiceAssignment("a-voice-yesterday", familyId, "NOT_STARTED");
    previous.taskDate = today.minusDays(1);
    VoiceMaterialTaskLinkEntity link = link(packageId, previous.id, "student-1");
    link.createMode = "AUTO";

    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(null);
    when(links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, "student-1"))
        .thenReturn(List.of(link));
    when(assignmentRepository.findById(previous.id)).thenReturn(Optional.of(previous));
    when(packages.findById(packageId)).thenReturn(Optional.of(item));
    when(assignments.carryOverToBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class), anyString()))
        .thenReturn(response(previous.id, "语文 · 语音作业"));

    service().autoCreateNext(familyId, "student-1");

    // 顺延也要占掉今天的自动额度，否则孩子今天做完这条后会立刻再拿到一份新的。
    ArgumentCaptor<VoiceMaterialAutoCreateRecordEntity> record =
        ArgumentCaptor.forClass(VoiceMaterialAutoCreateRecordEntity.class);
    verify(autoRecords).saveAndFlush(record.capture());
    assertEquals(today, record.getValue().businessDate);
    assertEquals(packageId, record.getValue().packageId);
    assertEquals(previous.id, record.getValue().assignmentId);
  }

  @Test
  void carryOverDoesNotInsertASecondRecordForTheSameBusinessDay() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    LocalDate today = LocalDate.now(ZoneId.of("Asia/Shanghai"));
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-语文", "READY");

    // 这条任务本来就是今天自动建出来的（家长随后把日期改到了昨天），今天的额度记录早就在了。
    AssignmentEntity previous = voiceAssignment("a-voice-today", familyId, "NOT_STARTED");
    previous.taskDate = today.minusDays(1);
    VoiceMaterialTaskLinkEntity link = link(packageId, previous.id, "student-1");
    link.createMode = "AUTO";

    VoiceMaterialAutoCreateRecordEntity existing = new VoiceMaterialAutoCreateRecordEntity();
    existing.id = UUID.randomUUID();
    existing.familyId = familyId;
    existing.studentId = "student-1";
    existing.businessDate = today;
    existing.packageId = packageId;
    existing.assignmentId = previous.id;

    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(null);
    when(links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, "student-1"))
        .thenReturn(List.of(link));
    when(assignmentRepository.findById(previous.id)).thenReturn(Optional.of(previous));
    when(packages.findById(packageId)).thenReturn(Optional.of(item));
    when(assignments.carryOverToBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class), anyString()))
        .thenReturn(response(previous.id, "语文 · 语音作业"));
    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(Optional.of(existing));

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertTrue(result.carriedOver());
    // 直接 insert 会撞上 uq_voice_material_auto_daily，把整次自动创建拖成 500。
    verify(autoRecords, never()).saveAndFlush(any(VoiceMaterialAutoCreateRecordEntity.class));
  }

  @Test
  void submittedAutoTaskFromPreviousDayDoesNotBlockNewAutomaticCreation() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    LocalDate today = LocalDate.now(ZoneId.of("Asia/Shanghai"));
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "002-数学", "READY");
    AssignmentDtos.Response created = response("a-voice-today", "数学 · 语音作业");

    AssignmentEntity previous = voiceAssignment("a-voice-submitted", familyId, "SUBMITTED");
    previous.taskDate = today.minusDays(1);
    VoiceMaterialTaskLinkEntity link = link(UUID.randomUUID(), previous.id, "student-1");
    link.createMode = "AUTO";

    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(null);
    when(links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, "student-1"))
        .thenReturn(List.of(link));
    when(assignmentRepository.findById(previous.id)).thenReturn(Optional.of(previous));
    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(Optional.empty());
    when(packages.findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
        familyId, "student-1")).thenReturn(List.of(item));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    // 孩子昨天已经交出去了，今天应该照常拿到新的一份，而不是把旧的又拉回来。
    assertTrue(result.created());
    assertFalse(result.carriedOver());
    assertEquals(created.id(), result.assignmentId());
    verify(assignments, never()).carryOverToBusinessDate(any(), anyString(), any(), any());
  }

  @Test
  void manualAndLegacyTasksAreNeverCarriedOver() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    LocalDate today = LocalDate.now(ZoneId.of("Asia/Shanghai"));
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "003-英语", "READY");
    AssignmentDtos.Response created = response("a-voice-today", "英语 · 语音作业");

    // 家长手工建的任务带着家长自己选的日期，迁移前的历史任务语义不明，两者都不该被系统挪走。
    AssignmentEntity manual = voiceAssignment("a-voice-manual", familyId, "NOT_STARTED");
    manual.taskDate = today.minusDays(3);
    VoiceMaterialTaskLinkEntity manualLink = link(UUID.randomUUID(), manual.id, "student-1");
    manualLink.createMode = "MANUAL";

    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(null);
    when(links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(familyId, "student-1"))
        .thenReturn(List.of(manualLink));
    when(assignmentRepository.findById(manual.id)).thenReturn(Optional.of(manual));
    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(Optional.empty());
    when(packages.findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
        familyId, "student-1")).thenReturn(List.of(item));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1");

    assertTrue(result.created());
    assertFalse(result.carriedOver());
    assertEquals(today.minusDays(3), manual.taskDate);
    verify(assignments, never()).carryOverToBusinessDate(any(), anyString(), any(), any());
  }

  @Test
  void automaticCreationCanFilterMaterialByRequestedSubject() {
    UUID familyId = UUID.randomUUID();
    UUID chineseId = UUID.randomUUID();
    UUID mathId = UUID.randomUUID();
    VoiceMaterialPackageEntity chinese = packageEntity(familyId, chineseId, "001-语文", "READY");
    VoiceMaterialPackageEntity math = packageEntity(familyId, mathId, "002-数学", "READY");
    math.subjectCode = "MATH";
    math.title = "口算练习";
    AssignmentDtos.Response created = response("a-voice-math", "数学 · 语音作业");

    when(autoRecords.findByFamilyIdAndStudentIdAndBusinessDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(Optional.empty());
    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(null);
    when(packages.findByFamilyIdAndStudentIdOrderByDirectoryNameAscCreatedAtAsc(
        familyId, "student-1")).thenReturn(List.of(chinese, math));
    when(links.findByFamilyIdAndStudentIdOrderByCreatedAtDesc(
        familyId, "student-1")).thenReturn(List.of());
    when(packages.lockOwned(familyId, mathId)).thenReturn(Optional.of(math));
    when(assignments.nextVoiceMaterialTaskTitle(
        any(UUID.class), anyString(), org.mockito.ArgumentMatchers.eq("MATH"),
        any(LocalDate.class), anyString())).thenReturn("数学 · 语音作业");
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, mathId)).thenReturn(List.of());

    VoiceMaterialDtos.AutoCreateResponse result =
        service().autoCreateNext(familyId, "student-1", "MATH");

    assertTrue(result.created());
    assertEquals(mathId.toString(), result.packageId());
    verify(packages).lockOwned(familyId, mathId);
    verify(packages, never()).lockOwned(familyId, chineseId);
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
            "student-1", "CHINESE", 18, "2026-09-28", "语文 · 第二次语音作业", "", "req-2"));

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
    when(assignments.findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class))).thenReturn(active);
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenReturn(created);
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());

    VoiceMaterialDtos.CreateAssignmentResponse result = service().createManually(
        familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            "student-1", "MATH", 15, "2026-09-28", "数学 · 手工语音作业", "", "req-parallel"));

    assertTrue(result.created());
    assertEquals(created.id(), result.assignmentId());
    verify(assignments, never()).findFirstVoiceMaterialTaskForDate(
        any(UUID.class), anyString(), any(LocalDate.class));
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
            "student-1", null, 15, "2026-09-28", "", "", "req-1"));

    assertFalse(result.created());
    assertEquals(existing.id(), result.assignmentId());
    assertEquals(existing.id(), result.assignment().id());
    verify(assignments, never()).create(any(), anyString(), any());
  }


  @Test
  void manualCreationDefaultsMissingTaskDateToBusinessToday() {
    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = packageEntity(familyId, packageId, "001-课文朗读", "READY");
    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(files.findByFamilyIdAndPackageIdOrderBySortOrderAscCreatedAtAsc(
        familyId, packageId)).thenReturn(List.of());
    when(assignments.create(any(UUID.class), anyString(), any(AssignmentDtos.Create.class)))
        .thenAnswer(invocation -> {
          AssignmentDtos.Create input = invocation.getArgument(2);
          return new AssignmentDtos.Response(
              input.id(), "student-1", input.assignmentType(), input.subjectCode(),
              input.contentType(), input.subject(), input.title(), input.instruction(),
              input.textbookRef(), input.taskDate(), input.status(), input.sourceLabel(),
              input.sourceExcerpt(), input.expectedMinutes(), 0L, 0L, 0L, "", 0L);
        });

    LocalDate expectedToday = LocalDate.now(ZoneId.of("Asia/Shanghai"));
    VoiceMaterialDtos.CreateAssignmentResponse result = service().createManually(
        familyId,
        packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            "student-1", "CHINESE", 20, null, "当天语音作业", "完成当天语音任务", "req-default-date"));

    ArgumentCaptor<AssignmentDtos.Create> input =
        ArgumentCaptor.forClass(AssignmentDtos.Create.class);
    verify(assignments).create(any(UUID.class), org.mockito.ArgumentMatchers.eq("student-1"), input.capture());
    assertEquals(expectedToday.toString(), input.getValue().taskDate());
    assertTrue(result.created());
  }

  @Test
  void manualCreationUsesTitleTaskDateAndExpectedMinutes() {
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

    String taskDate = "2026-09-25";
    VoiceMaterialDtos.CreateAssignmentResponse result = service().createManually(
        familyId, packageId,
        new VoiceMaterialDtos.CreateAssignmentRequest(
            "student-1", "ENGLISH", 30, taskDate, "自定义语音作业", "先听两遍并跟读。", "req-custom"));

    ArgumentCaptor<AssignmentDtos.Create> input =
        ArgumentCaptor.forClass(AssignmentDtos.Create.class);
    verify(assignments).create(any(UUID.class), org.mockito.ArgumentMatchers.eq("student-1"), input.capture());
    assertEquals(30, input.getValue().expectedMinutes());
    assertEquals(taskDate, input.getValue().taskDate());
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
            "student-2", null, 15, "2026-09-28", "", "", "req-cross"));

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
        "", "2026-09-28", "NOT_STARTED",
        "语音素材库", "001-课文朗读", 15,
        0L, 0L, 0L, "", 0L);
  }
}
