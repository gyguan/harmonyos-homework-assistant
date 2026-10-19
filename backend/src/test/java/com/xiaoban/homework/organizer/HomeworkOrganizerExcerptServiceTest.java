package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

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

class HomeworkOrganizerExcerptServiceTest {
  private static HomeworkOrganizerDtos.Candidate unclear(String excerpt) {
    return new HomeworkOrganizerDtos.Candidate(
        "语文", "完成摘抄（4+2）", "完成摘抄（4+2）", "待家长确认",
        "2026-10-19", 20, excerpt, 0.9, "", "", "", 0, "");
  }

  @Test void textAndImageBothEnforcePreviouslyConfirmedFeedbackAfterModelCompletion()
      throws Exception {
    UUID family = UUID.randomUUID();
    var student = new StudentEntity() {};
    student.id = "child1";
    student.familyId = family;
    var students = mock(StudentRepository.class);
    when(students.findById("child1")).thenReturn(Optional.of(student));
    var repo = mock(HomeworkTeacherExperienceRepository.class);
    var learned = new HomeworkTeacherExperienceEntity();
    learned.id = UUID.randomUUID();
    learned.studentId = "child1";
    learned.familyId = family;
    learned.teacherName = "学科归属:语文";
    learned.subject = "语文";
    learned.cue = "摘抄：（4+2）"; // old feedback remains a literal cue
    learned.exampleSource = "摘抄：（4+2）";
    learned.interpretation = "家长反馈：4+2表示4个好词，2个好句";
    learned.origin = "FEEDBACK_AUTO";
    learned.active = true;
    when(repo.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(learned));
    var experience = new HomeworkTeacherExperienceService(repo, students);

    var ai = mock(HomeworkOrganizerModelClient.class);
    when(ai.available()).thenReturn(true);
    when(ai.imageAvailable()).thenReturn(true);
    when(ai.organize(eq(student), anyString(), anyString()))
        .thenReturn(Optional.of(List.of(unclear("摘抄：（4+2）"))));
    when(ai.organizeImage(eq(student), anyString(), anyString(), anyString()))
        .thenReturn(Optional.of(new HomeworkOrganizerDtos.ImageResponse(
            List.of(unclear("摘抄：（4+2）")), "AI_IMAGE", "摘抄：（4+2）")));

    var service = new HomeworkOrganizerService(students, ai, null, null, experience);
    var text = service.organize(family, "child1",
        new HomeworkOrganizerDtos.Request("摘抄：（4+2）", "老师的文字通知"));
    assertEquals("完成摘抄4个好词、2个好句", text.assignments().getFirst().title());
    assertTrue(text.assignments().getFirst().instruction().contains("4个好词、2个好句"));

    var png = new BufferedImage(2, 2, BufferedImage.TYPE_INT_RGB);
    var buffer = new ByteArrayOutputStream();
    assertTrue(ImageIO.write(png, "PNG", buffer));
    var image = service.organizeImage(family, "child1",
        new HomeworkOrganizerDtos.ImageRequest(
            Base64.getEncoder().encodeToString(buffer.toByteArray()),
            "image/png", "家长拍照上传", "", "", "img-batch1"));
    assertEquals("完成摘抄4个好词、2个好句", image.assignments().getFirst().title());
    assertEquals("摘抄：（4+2）", image.assignments().getFirst().sourceExcerpt());
  }
}
