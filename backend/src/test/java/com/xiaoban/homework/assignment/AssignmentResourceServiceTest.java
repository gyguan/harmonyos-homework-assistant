package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;

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
