package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.xiaoban.homework.common.ApiExceptions;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

class VoiceMediaPolicyTest {
  private final VoiceMediaPolicy policy = new VoiceMediaPolicy();

  @Test
  void acceptsPngWhenMetadataAndSignatureAgree() {
    byte[] png = new byte[] {
        (byte) 0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a,
        0, 0, 0, 0
    };
    assertDoesNotThrow(() -> policy.validateImage(
        new MockMultipartFile("file", "homework.png", "image/png", png)));
  }

  @Test
  void rejectsImageWhoseExtensionDoesNotMatchContent() {
    byte[] png = new byte[] {
        (byte) 0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a,
        0, 0, 0, 0
    };
    assertThrows(ApiExceptions.BadRequest.class, () -> policy.validateImage(
        new MockMultipartFile("file", "homework.jpg", "image/jpeg", png)));
  }

  @Test
  void rejectsArbitraryBytesEvenWithImageMetadata() {
    assertThrows(ApiExceptions.BadRequest.class, () -> policy.validateImage(
        new MockMultipartFile("file", "homework.jpg", "image/jpeg",
            new byte[] {1, 2, 3, 4, 5})));
  }

  @Test
  void acceptsWavSignature() {
    byte[] wav = new byte[] {
        'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'A', 'V', 'E', 0, 0, 0, 0
    };
    assertDoesNotThrow(() -> policy.validateAudio(
        new MockMultipartFile("file", "voice.wav", "audio/wav", wav)));
  }
}
