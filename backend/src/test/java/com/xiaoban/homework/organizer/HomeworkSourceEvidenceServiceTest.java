package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class HomeworkSourceEvidenceServiceTest {
  @Test void persistedEvidenceIsScopedImmutableAndKeepsEmptyBatch() {
    var repository = mock(HomeworkSourceEvidenceRepository.class);
    var students = mock(StudentRepository.class);
    var snapshots = mock(HomeworkOrganizerAiSnapshotService.class);
    var student = new ConfigurableHomeworkOrganizerModelClientTest.TestStudent();
    student.id="s"; student.familyId=UUID.randomUUID();
    when(students.findById("s")).thenReturn(Optional.of(student));
    var service = new HomeworkSourceEvidenceService(repository, students, snapshots, JsonMapper.builder().build());
    var doc = HomeworkSourceDocument.text("通知原文");
    when(repository.findByFamilyIdAndStudentIdAndBatchId(student.familyId,"s","batch")).thenReturn(Optional.empty());
    service.capture(student.familyId,"s","batch","",List.of(),doc,List.of(),false);
    var saved = org.mockito.ArgumentCaptor.forClass(HomeworkSourceEvidenceEntity.class);
    verify(repository).save(saved.capture());
    when(repository.findByFamilyIdAndStudentIdAndBatchId(student.familyId,"s","batch")).thenReturn(Optional.of(saved.getValue()));
    assertEquals(doc, service.get(student.familyId,"s","batch").sourceDocument());
    assertThrows(ApiExceptions.BadRequest.class, () -> service.capture(student.familyId,"s","batch","",List.of(),HomeworkSourceDocument.text("不同原文"),List.of(),false));
    assertThrows(ApiExceptions.NotFound.class, () -> service.get(UUID.randomUUID(),"s","batch"));
    verify(snapshots).capture(student.familyId,"s","batch","",List.of());
  }
}
