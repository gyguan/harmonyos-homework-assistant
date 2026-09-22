package com.xiaoban.homework.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
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

class MediaAssetServiceTest {
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
