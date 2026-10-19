package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkStudentTeacherServiceTest {
  static class Student extends StudentEntity { Student() { super(); } }

  @Test
  void registersAndVerifiesTeacherScopedToOneStudent() {
    var family = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    var student = new Student();
    student.id = "s1";
    student.familyId = family;
    when(students.findById("s1")).thenReturn(Optional.of(student));
    var repository = mock(HomeworkStudentTeacherRepository.class);
    when(repository.save(any(HomeworkStudentTeacherEntity.class))).thenAnswer(i -> i.getArgument(0));
    var service = new HomeworkStudentTeacherService(repository, students);
    var input = new HomeworkStudentTeacherService.TeacherInput("王老师", "语文");
    var saved = service.register(family, "s1", input);
    assertEquals("王老师", saved.teacherName());
    var registered = new HomeworkStudentTeacherEntity();
    registered.familyId = family;
    registered.studentId = "s1";
    registered.teacherName = "王老师";
    registered.subject = "语文";
    registered.enabled = true;
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "s1"))
        .thenReturn(List.of(registered));
    assertEquals("王老师", service.verifiedTeacher(family, "s1", "王老师"));
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.verifiedTeacher(family, "s1", "李老师"));
    assertThrows(ApiExceptions.NotFound.class,
        () -> service.list(UUID.randomUUID(), "s1"));
  }

  @Test
  void refusesTeacherBindingFromAnotherChild() {
    var family = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    var student = new Student();
    student.id = "s1";
    student.familyId = family;
    when(students.findById("s1")).thenReturn(Optional.of(student));
    var repo = mock(HomeworkStudentTeacherRepository.class);
    var service = new HomeworkStudentTeacherService(repo, students);
    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.verifiedTeacher(family, "s1", "王老师"));
    assertThrows(ApiExceptions.NotFound.class,
        () -> service.verifiedTeacher(family, "s2", "王老师"));
  }
}
