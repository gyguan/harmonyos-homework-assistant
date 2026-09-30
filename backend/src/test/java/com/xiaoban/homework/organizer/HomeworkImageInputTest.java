package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;

class HomeworkImageInputTest {
  @Test
  void acceptsOldImageJsonAndValidatesOptionalSupplementaryText() throws Exception {
    var mapper = tools.jackson.databind.json.JsonMapper.builder().build();
    var oldRequest = mapper.readValue("{\"imageBase64\":\"" + png()
        + "\",\"contentType\":\"image/png\",\"sourceLabel\":\"图片\"}", HomeworkOrganizerDtos.ImageRequest.class);
    assertNull(oldRequest.text());
    assertTrue(HomeworkImageInput.dataUrl(oldRequest).startsWith("data:image/png;base64,"));
    try (var factory = jakarta.validation.Validation.buildDefaultValidatorFactory()) {
      var validator = factory.getValidator();
      assertTrue(validator.validate(oldRequest).isEmpty());
      assertTrue(validator.validate(new HomeworkOrganizerDtos.ImageRequest(png(), "image/png", "图片", "x".repeat(12000))).isEmpty());
      var violations = validator.validate(new HomeworkOrganizerDtos.ImageRequest(png(), "image/png", "图片", "x".repeat(12001)));
      assertEquals(1, violations.size());
      assertEquals("text", violations.iterator().next().getPropertyPath().toString());
    }
  }

  @Test
  void passesSupplementaryTextToImageModel() throws Exception {
    var students = mock(StudentRepository.class);
    var model = mock(HomeworkOrganizerModelClient.class);
    var service = new HomeworkOrganizerService(students, model);
    var family = UUID.randomUUID();
    StudentEntity student = new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    student.familyId = family;
    when(students.findById("student-1")).thenReturn(Optional.of(student));
    when(model.imageAvailable()).thenReturn(true);
    when(model.organizeImage(eq(student), eq("图片"), startsWith("data:image/png;base64,"), eq("数学口算20题")))
        .thenReturn(Optional.of(new HomeworkOrganizerDtos.ImageResponse(List.of(), "AI_IMAGE", "图片文字")));
    service.organizeImage(family, "student-1", new HomeworkOrganizerDtos.ImageRequest(png(), "image/png", "图片", "数学口算20题"));
    verify(model).organizeImage(eq(student), eq("图片"), startsWith("data:image/png;base64,"), eq("数学口算20题"));
  }

  static String png() throws Exception {
    var bytes = new ByteArrayOutputStream();
    ImageIO.write(new BufferedImage(2, 2, BufferedImage.TYPE_INT_RGB), "png", bytes);
    return Base64.getEncoder().encodeToString(bytes.toByteArray());
  }

  @Test
  void acceptsARealImageAndRejectsSpoofedInvalidAndOversizedInputs() throws Exception {
    String png = png();
    assertEquals("data:image/png;base64," + png,
        HomeworkImageInput.dataUrl(new HomeworkOrganizerDtos.ImageRequest(png, "image/png", "截图", null)));
    for (var request : List.of(
        new HomeworkOrganizerDtos.ImageRequest(png, "image/jpeg", "截图", null),
        new HomeworkOrganizerDtos.ImageRequest(png, "image/svg+xml", "截图", null),
        new HomeworkOrganizerDtos.ImageRequest("not-base64!", "image/png", "截图", null),
        new HomeworkOrganizerDtos.ImageRequest("dGV4dA==", "image/png", "截图", null),
        new HomeworkOrganizerDtos.ImageRequest("A".repeat(HomeworkImageInput.MAX_BASE64_CHARS + 4), "image/png", "截图", null))) {
      assertThrows(ApiExceptions.BadRequest.class, () -> HomeworkImageInput.dataUrl(request));
    }
  }

  @Test
  void checksFamilyBeforeAnyModelCallAndKeepsParsedSubjects() throws Exception {
    var students = mock(StudentRepository.class);
    var model = mock(HomeworkOrganizerModelClient.class);
    var service = new HomeworkOrganizerService(students, model);
    var family = UUID.randomUUID();
    StudentEntity student = new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    student.familyId = family;
    when(students.findById("student-1")).thenReturn(Optional.of(student));
    var request = new HomeworkOrganizerDtos.ImageRequest(png(), "image/png", "图片", null);
    assertThrows(ApiExceptions.NotFound.class, () -> service.organizeImage(UUID.randomUUID(), "student-1", request));
    verifyNoInteractions(model);
    when(model.imageAvailable()).thenReturn(true);
    var chinese = new HomeworkOrganizerDtos.Candidate("语文", "朗读", "朗读课文", "", "今天", 10, "朗读", .9);
    var math = new HomeworkOrganizerDtos.Candidate("数学", "口算", "口算20题", "", "今天", 10, "口算", .9);
    var expected = new HomeworkOrganizerDtos.ImageResponse(List.of(chinese, math), "AI_IMAGE", "语文朗读；数学口算");
    when(model.organizeImage(eq(student), eq("图片"), startsWith("data:image/png;base64,"), isNull()))
        .thenReturn(Optional.of(expected));
    var actual = service.organizeImage(family, "student-1", request);
    assertEquals(List.of("语文", "数学"), actual.assignments().stream().map(HomeworkOrganizerDtos.Candidate::subject).toList());
    assertEquals("AI_IMAGE", actual.mode());
    when(model.organizeImage(any(), any(), any(), any())).thenReturn(Optional.empty());
    assertThrows(ApiExceptions.ServiceUnavailable.class, () -> service.organizeImage(family, "student-1", request));
  }
}
