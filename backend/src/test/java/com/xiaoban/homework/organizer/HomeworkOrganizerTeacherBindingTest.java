package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class HomeworkOrganizerTeacherBindingTest {
  static class Student extends StudentEntity { Student() { super(); } }

  @Test
  void modelReceivesVerifiedTeacherWithoutRewritingOriginalRequest() {
    UUID family = UUID.randomUUID();
    var student = new Student();
    student.id = "s1";
    student.familyId = family;
    var students = mock(StudentRepository.class);
    when(students.findById("s1")).thenReturn(Optional.of(student));
    var teachers = mock(HomeworkStudentTeacherService.class);
    when(teachers.verifiedTeacher(family, "s1", "王老师")).thenReturn("王老师");
    var model = mock(HomeworkOrganizerModelClient.class);
    when(model.available()).thenReturn(true);
    when(model.organize(eq(student), anyString(), eq("朗读国13")))
        .thenReturn(Optional.of(List.of()));
    var service = new HomeworkOrganizerService(students, model, teachers);
    var request = new HomeworkOrganizerDtos.Request("朗读国13", "家长录入文字", "王老师");
    service.organize(family, "s1", request);
    var label = ArgumentCaptor.forClass(String.class);
    verify(model).organize(eq(student), label.capture(), eq("朗读国13"));
    assertTrue(label.getValue().contains("[家长已确认老师：王老师]"));
    assertEquals("家长录入文字", request.sourceLabel());
    verify(teachers).verifiedTeacher(family, "s1", "王老师");
  }

  @Test
  void noTeacherSpecifiedKeepsBackwardCompatiblePromptSource() {
    UUID family = UUID.randomUUID();
    var student = new Student();
    student.id = "s1";
    student.familyId = family;
    var students = mock(StudentRepository.class);
    when(students.findById("s1")).thenReturn(Optional.of(student));
    var model = mock(HomeworkOrganizerModelClient.class);
    when(model.available()).thenReturn(true);
    when(model.organize(eq(student), eq("原始来源"), eq("读国13")))
        .thenReturn(Optional.of(List.of()));
    var service = new HomeworkOrganizerService(students, model);
    service.organize(family, "s1", new HomeworkOrganizerDtos.Request("读国13", "原始来源"));
    verify(model).organize(eq(student), eq("原始来源"), eq("读国13"));
  }
  @Test
  void originalSourceUniquelyNamedTeacherIsStoredWithoutRegisteringTeacher() {
    UUID family = UUID.randomUUID();
    var student = new Student();
    student.id = "s1";
    student.familyId = family;
    var students = mock(StudentRepository.class);
    when(students.findById("s1")).thenReturn(Optional.of(student));
    var model = mock(HomeworkOrganizerModelClient.class);
    when(model.available()).thenReturn(true);
    when(model.organize(eq(student), eq("家长录入文字"), eq("王老师：朗读国13")))
        .thenReturn(Optional.of(List.of()));
    var snapshots = mock(HomeworkOrganizerAiSnapshotService.class);
    var service = new HomeworkOrganizerService(students, model, null, snapshots);
    service.organize(family, "s1",
        new HomeworkOrganizerDtos.Request("王老师：朗读国13", "家长录入文字", "", "text-100"));
    verify(snapshots).capture(eq(family), eq("s1"), eq("text-100"), eq("王老师"), anyList());
  }

}
