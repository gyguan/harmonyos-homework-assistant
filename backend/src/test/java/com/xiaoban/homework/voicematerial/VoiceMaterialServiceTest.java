package com.xiaoban.homework.voicematerial;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentRepository;
import com.xiaoban.homework.assignment.VoiceMediaPolicy;
import com.xiaoban.homework.media.MediaAssetRepository;
import com.xiaoban.homework.media.MediaAssetService;
import com.xiaoban.homework.student.StudentService;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.mock.web.MockMultipartFile;

class VoiceMaterialServiceTest {
  @Test
  void fileUploadRetryReturnsExistingPackageFileWithoutStoringMediaAgain() {
    VoiceMaterialBatchRepository batches = mock(VoiceMaterialBatchRepository.class);
    VoiceMaterialPackageRepository packages = mock(VoiceMaterialPackageRepository.class);
    VoiceMaterialFileRepository files = mock(VoiceMaterialFileRepository.class);
    VoiceMaterialTaskLinkRepository links = mock(VoiceMaterialTaskLinkRepository.class);
    VoiceMaterialAutoCreateRecordRepository autoRecords =
        mock(VoiceMaterialAutoCreateRecordRepository.class);
    AssignmentRepository assignments = mock(AssignmentRepository.class);
    MediaAssetRepository assets = mock(MediaAssetRepository.class);
    MediaAssetService mediaAssets = mock(MediaAssetService.class);
    StudentService students = mock(StudentService.class);

    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = new VoiceMaterialPackageEntity();
    item.id = packageId;
    item.familyId = familyId;
    item.studentId = "student-1";
    item.status = "UPLOADING";

    VoiceMaterialFileEntity existing = new VoiceMaterialFileEntity();
    existing.id = UUID.randomUUID();
    existing.packageId = packageId;
    existing.familyId = familyId;
    existing.assetId = UUID.randomUUID();
    existing.resourceType = "AUDIO";
    existing.relativeName = "voice.mp3";
    existing.sortOrder = 0;

    when(packages.findOwnedStudentId(familyId, packageId)).thenReturn(Optional.of("student-1"));
    when(packages.lockOwned(familyId, packageId)).thenReturn(Optional.of(item));
    when(files.findByFamilyIdAndPackageIdAndResourceTypeAndRelativeName(
        familyId, packageId, "AUDIO", "voice.mp3"))
        .thenReturn(Optional.of(existing));

    VoiceMaterialService service = new VoiceMaterialService(
        batches, packages, files, links, autoRecords, assignments, assets, mediaAssets, students,
        new VoiceMediaPolicy());

    VoiceMaterialDtos.FileResponse result = service.uploadFile(
        familyId, packageId, "AUDIO", "voice.mp3", 0,
        new MockMultipartFile("file", "voice.mp3", "audio/mpeg",
            new byte[] {'I', 'D', '3', 4, 0, 0, 0, 0, 0, 0}));

    assertEquals(existing.id.toString(), result.id());
    verify(students).requireOwnedForUpdate(familyId, "student-1");
    verify(mediaAssets, never()).store(any(), any());
  }

  @Test
  void batchDeletePackagesClearsAutoCreateRecordsBeforeDeletingFolders() {
    VoiceMaterialBatchRepository batches = mock(VoiceMaterialBatchRepository.class);
    VoiceMaterialPackageRepository packages = mock(VoiceMaterialPackageRepository.class);
    VoiceMaterialFileRepository files = mock(VoiceMaterialFileRepository.class);
    VoiceMaterialTaskLinkRepository links = mock(VoiceMaterialTaskLinkRepository.class);
    VoiceMaterialAutoCreateRecordRepository autoRecords =
        mock(VoiceMaterialAutoCreateRecordRepository.class);
    AssignmentRepository assignments = mock(AssignmentRepository.class);
    MediaAssetRepository assets = mock(MediaAssetRepository.class);
    MediaAssetService mediaAssets = mock(MediaAssetService.class);
    StudentService students = mock(StudentService.class);

    UUID familyId = UUID.randomUUID();
    UUID packageId = UUID.randomUUID();
    VoiceMaterialPackageEntity item = new VoiceMaterialPackageEntity();
    item.id = packageId;
    item.familyId = familyId;
    item.studentId = "student-1";
    item.directoryName = "001-语文朗读";
    when(packages.findById(packageId)).thenReturn(Optional.of(item));
    when(autoRecords.deleteByFamilyIdAndPackageIdIn(familyId, List.of(packageId)))
        .thenReturn(1L);

    VoiceMaterialService service = new VoiceMaterialService(
        batches, packages, files, links, autoRecords, assignments, assets, mediaAssets, students,
        new VoiceMediaPolicy());

    String missingId = UUID.randomUUID().toString();
    VoiceMaterialDtos.BatchDeleteResponse result =
        service.batchDeletePackages(familyId, List.of(packageId.toString(), missingId, " "));

    assertEquals(2, result.requested());
    assertEquals(1, result.deleted());
    assertEquals(1, result.skipped());
    VoiceMaterialDtos.BatchDeleteItem deleted = result.items().get(0);
    assertEquals("001-语文朗读", deleted.label());
    assertTrue(deleted.deleted());
    assertFalse(result.items().get(1).deleted());
    assertEquals("素材目录不存在或无权访问", result.items().get(1).reason());

    // voice_material_auto_create_record.package_id 没有 on delete cascade，
    // 必须先清记录再删目录，否则线上会直接撞外键。
    InOrder order = inOrder(autoRecords, packages);
    order.verify(autoRecords).deleteByFamilyIdAndPackageIdIn(familyId, List.of(packageId));
    order.verify(packages).deleteAll(List.of(item));
    // media_asset 是跨任务去重复用的，删目录不能动它，否则已生成的语音任务会取不到素材。
    verifyNoInteractions(assets);
  }

  @Test
  void batchDeletePackagesNormalizesAndDeduplicatesIds() {
    VoiceMaterialBatchRepository batches = mock(VoiceMaterialBatchRepository.class);
    VoiceMaterialPackageRepository packages = mock(VoiceMaterialPackageRepository.class);
    VoiceMaterialAutoCreateRecordRepository autoRecords =
        mock(VoiceMaterialAutoCreateRecordRepository.class);

    VoiceMaterialService service = new VoiceMaterialService(
        batches, packages, mock(VoiceMaterialFileRepository.class),
        mock(VoiceMaterialTaskLinkRepository.class), autoRecords,
        mock(AssignmentRepository.class), mock(MediaAssetRepository.class),
        mock(MediaAssetService.class), mock(StudentService.class), new VoiceMediaPolicy());

    String packageId = UUID.randomUUID().toString();
    // 故意混入重复项、null 与空白串：归一化后应只剩 1 个，且因查不到目录而整体跳过。
    VoiceMaterialDtos.BatchDeleteResponse result = service.batchDeletePackages(
        UUID.randomUUID(), Arrays.asList(packageId, packageId, null, " "));

    assertEquals(1, result.requested());
    assertEquals(0, result.deleted());
    verify(autoRecords, never()).deleteByFamilyIdAndPackageIdIn(any(), any());
  }
}
