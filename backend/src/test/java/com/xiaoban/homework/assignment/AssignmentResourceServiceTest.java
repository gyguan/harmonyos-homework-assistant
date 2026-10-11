package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import com.xiaoban.homework.media.MediaAssetEntity;
import java.util.UUID;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.media.MediaAssetService;
import com.xiaoban.homework.storage.FileStorage;
import com.xiaoban.homework.storage.FileTransactionCoordinator;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

class AssignmentResourceServiceTest {
  private AssignmentResourceService service() {
    return new AssignmentResourceService(
        mock(AssignmentService.class),
        mock(AssignmentResourceRepository.class),
        mock(FileStorage.class),
        mock(FileTransactionCoordinator.class),
        mock(MediaAssetService.class),
        new VoiceMediaPolicy());
  }

  @Test
  void regularAssignmentRejectsUnsupportedAttachments() {
    AssignmentResourceService service = service();
    assertThrows(ApiExceptions.BadRequest.class, () -> service.addResource(
        UUID.randomUUID(), "assignment-1", new MockMultipartFile(
            "file", "malware.exe", "application/octet-stream", new byte[] {1})));
  }

  @Test
  void regularAssignmentAcceptsVideoWithoutAudioOrImage() {
    UUID familyId = UUID.randomUUID();
    AssignmentService assignments = mock(AssignmentService.class);
    AssignmentResourceRepository resources = mock(AssignmentResourceRepository.class);
    MediaAssetService media = mock(MediaAssetService.class);
    AssignmentResourceService service = new AssignmentResourceService(
        assignments, resources, mock(FileStorage.class),
        mock(FileTransactionCoordinator.class), media, new VoiceMediaPolicy());
    when(resources.findByFamilyIdAndAssignmentIdOrderBySortOrderAscCreatedAtAsc(
        eq(familyId), eq("assignment-1"))).thenReturn(List.of());
    MediaAssetEntity asset = new MediaAssetEntity() {};
    asset.id = UUID.randomUUID();
    asset.originalName = "lesson.mp4";
    asset.contentType = "video/mp4";
    asset.sizeBytes = 3;
    when(media.store(eq(familyId), any())).thenReturn(asset);
    when(resources.saveAndFlush(any())).thenAnswer(call -> call.getArgument(0));

    AssignmentResourceDtos.Response added = service.addResource(
        familyId, "assignment-1", new MockMultipartFile(
            "file", "lesson.mp4", "video/mp4", new byte[] {1, 2, 3}));
    org.junit.jupiter.api.Assertions.assertEquals("VIDEO", added.resourceType());
    verify(media).store(eq(familyId), any());
  }

  @Test
  void voiceAssignmentRequiresAudio() {
    AssignmentResourceService service = service();
    List<MultipartFile> images = List.of(
        new MockMultipartFile("images", "scene.jpg", "image/jpeg", new byte[] {(byte) 0xff, (byte) 0xd8, (byte) 0xff, 0x00}));

    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.createVoiceAssignment(null, "student-1", null, null, images));
  }

  @Test
  void voiceAssignmentAllowsMoreThanNineImages() {
    AssignmentResourceService service = service();
    List<MultipartFile> images = new ArrayList<>();
    for (int i = 0; i < 12; i++) {
      images.add(new MockMultipartFile(
          "images", "scene-" + i + ".jpg", "image/jpeg",
          new byte[] {(byte) 0xff, (byte) 0xd8, (byte) 0xff, 0x00}));
    }

    assertDoesNotThrow(() -> service.validateImages(images));
  }
}
