package com.xiaoban.homework.student;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.assignment.AssignmentRepository;
import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.practice.PracticeAttemptRepository;
import com.xiaoban.homework.practice.PracticeGenerationEntity;
import com.xiaoban.homework.practice.PracticeGenerationRepository;
import com.xiaoban.homework.practice.PracticePaperAudienceRepository;
import com.xiaoban.homework.voicematerial.VoiceMaterialBatchRepository;
import com.xiaoban.homework.voicematerial.VoiceMaterialPackageRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class StudentServicePracticeGenerationTest {
  @Test
  void failedAndReadyDraftsAreCleanedInsteadOfBlockingDeletion() {
    Fixture fixture = new Fixture();
    PracticeGenerationEntity failed = generation("FAILED", Instant.now());
    PracticeGenerationEntity ready = generation("READY", Instant.now());
    when(fixture.generations.findByFamilyIdAndReferenceStudentId(
        fixture.familyId, fixture.student.id)).thenReturn(List.of(failed, ready));

    fixture.service.delete(fixture.familyId, fixture.student.id);

    verify(fixture.generations).deleteAll(List.of(failed, ready));
    verify(fixture.students).delete(fixture.student);
  }

  @Test
  void recentGeneratingDraftTemporarilyBlocksDeletion() {
    Fixture fixture = new Fixture();
    PracticeGenerationEntity generating = generation("GENERATING", Instant.now());
    when(fixture.generations.findByFamilyIdAndReferenceStudentId(
        fixture.familyId, fixture.student.id)).thenReturn(List.of(generating));

    assertThrows(ApiExceptions.Conflict.class, () ->
        fixture.service.delete(fixture.familyId, fixture.student.id));

    verify(fixture.students, never()).delete(fixture.student);
  }

  @Test
  void staleGeneratingDraftIsCleanedDuringDeletion() {
    Fixture fixture = new Fixture();
    PracticeGenerationEntity stale = generation(
        "GENERATING", Instant.now().minus(30, ChronoUnit.MINUTES));
    when(fixture.generations.findByFamilyIdAndReferenceStudentId(
        fixture.familyId, fixture.student.id)).thenReturn(List.of(stale));

    fixture.service.delete(fixture.familyId, fixture.student.id);

    verify(fixture.generations).deleteAll(List.of(stale));
    verify(fixture.students).delete(fixture.student);
  }

  private static PracticeGenerationEntity generation(String status, Instant updatedAt) {
    PracticeGenerationEntity generation = mock(PracticeGenerationEntity.class);
    generation.id = UUID.randomUUID();
    generation.status = status;
    generation.updatedAt = updatedAt;
    return generation;
  }

  private static final class Fixture {
    final UUID familyId = UUID.randomUUID();
    final StudentEntity student = new StudentEntity();
    final StudentRepository students = mock(StudentRepository.class);
    final PracticeGenerationRepository generations = mock(PracticeGenerationRepository.class);
    final StudentService service;

    Fixture() {
      student.id = "student-delete";
      student.familyId = familyId;
      student.name = "小宇";
      when(students.lockOwned(familyId, student.id)).thenReturn(Optional.of(student));
      when(students.countByFamilyId(familyId)).thenReturn(2L);

      service = new StudentService(
          students,
          mock(AssignmentRepository.class),
          mock(PracticeAttemptRepository.class),
          mock(PracticePaperAudienceRepository.class),
          generations,
          mock(VoiceMaterialBatchRepository.class),
          mock(VoiceMaterialPackageRepository.class));
    }
  }
}
