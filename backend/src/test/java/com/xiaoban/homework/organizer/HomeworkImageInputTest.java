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
  static String png() throws Exception {
    var bytes = new ByteArrayOutputStream();
    ImageIO.write(new BufferedImage(2, 2, BufferedImage.TYPE_INT_RGB), "png", bytes);
    return Base64.getEncoder().encodeToString(bytes.toByteArray());
  }

  @Test
  void acceptsARealImageAndRejectsSpoofedInvalidAndOversizedInputs() throws Exception {
    String png = png();
    assertEquals("data:image/png;base64," + png,
        HomeworkImageInput.dataUrl(new HomeworkOrganizerDtos.ImageRequest(png, "image/png", "截图")));
    for (var request : List.of(
        new HomeworkOrganizerDtos.ImageRequest(png, "image/jpeg", "截图"),
        new HomeworkOrganizerDtos.ImageRequest(png, "image/svg+xml", "截图"),
        new HomeworkOrganizerDtos.ImageRequest("not-base64!", "image/png", "截图"),
        new HomeworkOrganizerDtos.ImageRequest("dGV4dA==", "image/png", "截图"),
        new HomeworkOrganizerDtos.ImageRequest("A".repeat(HomeworkImageInput.MAX_BASE64_CHARS + 4), "image/png", "截图"))) {
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
    var request = new HomeworkOrganizerDtos.ImageRequest(png(), "image/png", "图片");
    assertThrows(ApiExceptions.NotFound.class, () -> service.organizeImage(UUID.randomUUID(), "student-1", request));
    verifyNoInteractions(model);
    when(model.imageAvailable()).thenReturn(true);
    var chinese = new HomeworkOrganizerDtos.Candidate("语文", "朗读", "朗读课文", "", "今天", 10, "朗读", .9);
    var math = new HomeworkOrganizerDtos.Candidate("数学", "口算", "口算20题", "", "今天", 10, "口算", .9);
    var expected = new HomeworkOrganizerDtos.ImageResponse(List.of(chinese, math), "AI_IMAGE", "语文朗读；数学口算");
    when(model.organizeImage(eq(student), eq("图片"), startsWith("data:image/png;base64,")))
        .thenReturn(Optional.of(expected));
    var actual = service.organizeImage(family, "student-1", request);
    assertEquals(List.of("语文", "数学"), actual.assignments().stream().map(HomeworkOrganizerDtos.Candidate::subject).toList());
    assertEquals("AI_IMAGE", actual.mode());
    when(model.organizeImage(any(), any(), any())).thenReturn(Optional.empty());
    assertThrows(ApiExceptions.ServiceUnavailable.class, () -> service.organizeImage(family, "student-1", request));
  }
}
