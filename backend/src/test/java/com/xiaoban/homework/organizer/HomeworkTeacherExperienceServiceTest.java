package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class HomeworkTeacherExperienceServiceTest {
  static class TestStudent extends StudentEntity {
    TestStudent() { super(); }
  }

  private static HomeworkTeacherExperienceEntity sample(UUID family, String studentId) {
    var record = new HomeworkTeacherExperienceEntity();
    record.id = UUID.randomUUID();
    record.familyId = family;
    record.studentId = studentId;
    record.teacherName = "王老师";
    record.subject = "语文";
    record.cue = "国13";
    record.interpretation = "国13 指《国学》第13页，不能猜测其他页码";
    record.exampleSource = "朗读国13";
    record.exampleResult = "朗读《国学》第13页";
    record.origin = "MANUAL";
    record.createdAt = Instant.now();
    record.updatedAt = Instant.now();
    return record;
  }

  @Test
  void textHintsNeedExactStudentTeacherAndCue() {
    var repository = mock(HomeworkTeacherExperienceRepository.class);
    var students = mock(StudentRepository.class);
    var family = UUID.randomUUID();
    var student = new TestStudent();
    student.id = "student-a";
    student.familyId = family;
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "student-a"))
        .thenReturn(List.of(sample(family, "student-a")));

    var service = new HomeworkTeacherExperienceService(repository, students);
    assertTrue(service.context(student, "群聊", "王老师：朗读国13", false).contains("《国学》第13页"));
    assertEquals("", service.context(student, "群聊", "李老师：朗读国13", false));
    assertEquals("", service.context(student, "群聊", "王老师：完成口算", false));

    var another = new TestStudent();
    another.id = "student-b";
    another.familyId = family;
    assertEquals("", service.context(another, "群聊", "王老师：朗读国13", false));
  }

  @Test
  void imageHintsAreConditionalAndStudentScoped() {
    var repository = mock(HomeworkTeacherExperienceRepository.class);
    var student = new TestStudent();
    student.id = "student-a";
    student.familyId = UUID.randomUUID();
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(student.familyId, student.id))
        .thenReturn(List.of(sample(student.familyId, student.id)));
    String context = new HomeworkTeacherExperienceService(repository, mock(StudentRepository.class))
        .context(student, "作业照片", "", true);
    assertEquals("", context);
    assertFalse(context.contains("student-b"));
  }

  @Test
  void confirmedEditUsesExplicitTeacherAndSkipsDuplicates() {
    var repository = mock(HomeworkTeacherExperienceRepository.class);
    var students = mock(StudentRepository.class);
    UUID family = UUID.randomUUID();
    var student = new TestStudent();
    student.id = "student-a";
    student.familyId = family;
    when(students.findById(student.id)).thenReturn(Optional.of(student));
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, student.id))
        .thenReturn(List.of());
    var service = new HomeworkTeacherExperienceService(repository, students);
    service.confirmedEdit(family, student.id, new HomeworkTeacherExperienceDtos.ConfirmedEdit(
        "王老师", "语文", "国13", "读国13", "朗读《国学》第13页"));
    var captor = ArgumentCaptor.forClass(HomeworkTeacherExperienceEntity.class);
    verify(repository).save(captor.capture());
    assertEquals("CONFIRMED_EDIT", captor.getValue().origin);
    assertEquals("student-a", captor.getValue().studentId);
    assertEquals("王老师", captor.getValue().teacherName);
  }

  @Test
  void rejectsAccessToOtherFamiliesStudent() {
    var students = mock(StudentRepository.class);
    var student = new TestStudent();
    student.id = "student-a";
    student.familyId = UUID.randomUUID();
    when(students.findById(student.id)).thenReturn(Optional.of(student));
    var service = new HomeworkTeacherExperienceService(
        mock(HomeworkTeacherExperienceRepository.class), students);
    assertThrows(ApiExceptions.NotFound.class,
        () -> service.list(UUID.randomUUID(), student.id));
  }
}
