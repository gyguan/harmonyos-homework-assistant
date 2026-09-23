package com.xiaoban.homework.voicematerial;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentRepository;
import com.xiaoban.homework.assignment.VoiceMediaPolicy;
import com.xiaoban.homework.media.MediaAssetRepository;
import com.xiaoban.homework.media.MediaAssetService;
import com.xiaoban.homework.student.StudentService;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class VoiceMaterialServiceTest {
  @Test
  void fileUploadRetryReturnsExistingPackageFileWithoutStoringMediaAgain() {
    VoiceMaterialBatchRepository batches = mock(VoiceMaterialBatchRepository.class);
    VoiceMaterialPackageRepository packages = mock(VoiceMaterialPackageRepository.class);
    VoiceMaterialFileRepository files = mock(VoiceMaterialFileRepository.class);
    VoiceMaterialTaskLinkRepository links = mock(VoiceMaterialTaskLinkRepository.class);
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
        batches, packages, files, links, assignments, assets, mediaAssets, students,
        new VoiceMediaPolicy());

    VoiceMaterialDtos.FileResponse result = service.uploadFile(
        familyId, packageId, "AUDIO", "voice.mp3", 0,
        new MockMultipartFile("file", "voice.mp3", "audio/mpeg", new byte[] {1, 2, 3}));

    assertEquals(existing.id.toString(), result.id());
    verify(students).requireOwnedForUpdate(familyId, "student-1");
    verify(mediaAssets, never()).store(any(), any());
  }
}
