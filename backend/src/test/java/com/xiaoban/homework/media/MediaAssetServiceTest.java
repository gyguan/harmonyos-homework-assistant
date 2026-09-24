package com.xiaoban.homework.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.family.FamilyEntity;
import com.xiaoban.homework.family.FamilyRepository;
import com.xiaoban.homework.storage.FileStorage;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

class MediaAssetServiceTest {

  @Test
  void newlyStoredPhysicalFileIsDeletedWhenSurroundingTransactionRollsBack() {
    MediaAssetRepository repository = mock(MediaAssetRepository.class);
    FileStorage storage = mock(FileStorage.class);
    FamilyRepository families = mock(FamilyRepository.class);
    UUID familyId = UUID.randomUUID();
    when(families.lockById(familyId)).thenReturn(Optional.of(
        new FamilyEntity(familyId, "回滚测试家庭", java.time.Instant.now())));
    when(repository.findByFamilyIdAndSha256AndSizeBytes(
        any(UUID.class), anyString(), anyLong())).thenReturn(Optional.empty());
    when(storage.save(any(), any())).thenReturn(
        new FileStorage.StoredFile("media/rollback.mp3", "voice.mp3", "audio/mpeg", 3L));
    when(repository.saveAndFlush(any(MediaAssetEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));

    TransactionSynchronizationManager.initSynchronization();
    try {
      MediaAssetEntity result = new MediaAssetService(repository, storage, families).store(
          familyId,
          new MockMultipartFile("file", "voice.mp3", "audio/mpeg", new byte[] {1, 2, 3}));

      assertFalse(TransactionSynchronizationManager.getSynchronizations().isEmpty());
      verify(storage, never()).delete("media/rollback.mp3");
      for (TransactionSynchronization synchronization :
          TransactionSynchronizationManager.getSynchronizations()) {
        synchronization.afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK);
      }
      verify(storage).delete("media/rollback.mp3");
      assertEquals("media/rollback.mp3", result.storagePath);
    } finally {
      TransactionSynchronizationManager.clearSynchronization();
    }
  }

  @Test
  void differentFamilyFilesWithSameSizeCreateDifferentAssets() {
    MediaAssetRepository repository = mock(MediaAssetRepository.class);
    FileStorage storage = mock(FileStorage.class);
    FamilyRepository families = mock(FamilyRepository.class);
    UUID familyId = UUID.randomUUID();
    when(families.lockById(familyId)).thenReturn(Optional.of(
        new FamilyEntity(familyId, "差异文件测试家庭", java.time.Instant.now())));
    when(repository.findByFamilyIdAndSha256AndSizeBytes(
        any(UUID.class), anyString(), anyLong())).thenReturn(Optional.empty());
    when(storage.save(any(), any())).thenAnswer(invocation -> {
      UUID id = invocation.getArgument(0);
      return new FileStorage.StoredFile("media/" + id + ".png", "image.png", "image/png", 3L);
    });
    when(repository.saveAndFlush(any(MediaAssetEntity.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));

    MediaAssetService service = new MediaAssetService(repository, storage, families);
    MediaAssetEntity first = service.store(familyId,
        new MockMultipartFile("file", "5.png", "image/png", new byte[] {1, 2, 3}));
    MediaAssetEntity second = service.store(familyId,
        new MockMultipartFile("file", "6.png", "image/png", new byte[] {1, 2, 4}));

    assertFalse(first.id.equals(second.id));
    verify(storage, org.mockito.Mockito.times(2)).save(any(), any());
  }

  @Test
  void identicalFamilyFileReusesExistingAssetWithoutCopyingAgain() {
    MediaAssetRepository repository = mock(MediaAssetRepository.class);
    FileStorage storage = mock(FileStorage.class);
    FamilyRepository families = mock(FamilyRepository.class);
    UUID familyId = UUID.randomUUID();
    when(families.lockById(familyId)).thenReturn(Optional.of(
        new FamilyEntity(familyId, "E2E家庭", java.time.Instant.now())));

    MediaAssetEntity existing = new MediaAssetEntity();
    existing.id = UUID.randomUUID();
    existing.familyId = familyId;
    existing.sha256 = "existing";
    existing.sizeBytes = 3;

    when(repository.findByFamilyIdAndSha256AndSizeBytes(
        any(UUID.class), anyString(), anyLong()))
        .thenReturn(Optional.of(existing));

    MediaAssetEntity result = new MediaAssetService(repository, storage, families).store(
        familyId,
        new MockMultipartFile("file", "voice.mp3", "audio/mpeg", new byte[] {1, 2, 3}));

    assertEquals(existing.id, result.id);
    verify(storage, never()).save(any(), any());
  }
}
