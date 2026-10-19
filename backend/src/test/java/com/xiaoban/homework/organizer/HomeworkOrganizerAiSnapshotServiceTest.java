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
import org.mockito.ArgumentCaptor;

class HomeworkOrganizerAiSnapshotServiceTest {
  static class Student extends StudentEntity { Student() { super(); } }

  private static HomeworkOrganizerDtos.Candidate candidate(String title) {
    return new HomeworkOrganizerDtos.Candidate("语文", title,
        "朗读并签字", "《国学》", "2026-10-19", 15, "国13", 0.9,
        "", "", "", 0.0, "");
  }

  @Test
  void storesServerOriginalsWithoutFullRawTextAndScopedByStudent() {
    UUID family = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    var student = new Student();
    student.id = "child-a";
    student.familyId = family;
    when(students.findById("child-a")).thenReturn(Optional.of(student));
    var repository = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var service = new HomeworkOrganizerAiSnapshotService(repository, students);
    service.capture(family, "child-a", "text-12345", "王老师", List.of(candidate("朗读国13")));
    var items = ArgumentCaptor.forClass(List.class);
    verify(repository).saveAll(items.capture());
    var row = (HomeworkOrganizerAiSnapshotEntity) items.getValue().getFirst();
    assertEquals("ai-text-12345-1", row.candidateId);
    assertEquals(family, row.familyId);
    assertEquals("child-a", row.studentId);
    assertEquals("王老师", row.teacherName);
    assertEquals("国13", row.sourceExcerpt);
    assertEquals("朗读国13", row.title);
    assertThrows(ApiExceptions.NotFound.class,
        () -> service.list(UUID.randomUUID(), "child-a", "text-12345"));
  }

  @Test
  void rejectsReusingSameImportIdWithDifferentAiResult() {
    UUID family = UUID.randomUUID();
    var students = mock(StudentRepository.class);
    var student = new Student();
    student.id = "s1";
    student.familyId = family;
    when(students.findById("s1")).thenReturn(Optional.of(student));
    var repository = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var existing = new HomeworkOrganizerAiSnapshotEntity();
    existing.candidateId = "ai-text-12345-1";
    existing.title = "朗读国13";
    existing.subject = "语文";
    when(repository.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        family, "s1", "text-12345")).thenReturn(List.of(existing));
    var service = new HomeworkOrganizerAiSnapshotService(repository, students);
    assertThrows(ApiExceptions.BadRequest.class, () ->
        service.capture(family, "s1", "text-12345", "王老师", List.of(candidate("朗读国14"))));
    verify(repository, never()).saveAll(any());
  }

  @Test
  void ignoresEmptyLegacyImportIdAndRejectsUnsafeNewId() {
    var repository = mock(HomeworkOrganizerAiSnapshotRepository.class);
    var students = mock(StudentRepository.class);
    var service = new HomeworkOrganizerAiSnapshotService(repository, students);
    service.capture(UUID.randomUUID(), "s1", "", "", List.of(candidate("test")));
    verifyNoInteractions(repository, students);
    UUID family = UUID.randomUUID();
    var student = new Student();
    student.id = "s1";
    student.familyId = family;
    when(students.findById("s1")).thenReturn(Optional.of(student));
    assertThrows(ApiExceptions.BadRequest.class, () ->
        service.capture(family, "s1", "../wrong", "", List.of(candidate("test"))));
  }
}
