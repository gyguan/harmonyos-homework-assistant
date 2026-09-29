package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.storage.FileTransactionCoordinator;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.submission.SubmissionPhotoRepository;
import com.xiaoban.homework.submission.SubmissionRepository;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

class AssignmentCreateIdempotencyTest {
  @Test
  void sameCreateRequestIsIdempotentButConflictingPayloadIsRejected() {
    AssignmentRepository repository = mock(AssignmentRepository.class);
    StudentService students = mock(StudentService.class);
    AtomicReference<AssignmentEntity> stored = new AtomicReference<>();
    when(repository.findById("assignment-idempotent"))
        .thenAnswer(invocation -> Optional.ofNullable(stored.get()));
    when(repository.saveAndFlush(any(AssignmentEntity.class))).thenAnswer(invocation -> {
      AssignmentEntity entity = invocation.getArgument(0);
      stored.set(entity);
      return entity;
    });

    AssignmentService service = new AssignmentService(
        repository,
        students,
        mock(SubmissionRepository.class),
        mock(SubmissionPhotoRepository.class),
        mock(AssignmentResourceRepository.class),
        mock(FileTransactionCoordinator.class));

    UUID familyId = UUID.randomUUID();
    AssignmentDtos.Create original = request("数学口算");
    AssignmentDtos.Response first = service.create(familyId, "student-1", original);
    AssignmentDtos.Response retry = service.create(familyId, "student-1", request("数学口算"));

    assertEquals(first.id(), retry.id());
    assertThrows(ApiExceptions.Conflict.class,
        () -> service.create(familyId, "student-1", request("篡改后的标题")));
  }

  private AssignmentDtos.Create request(String title) {
    return new AssignmentDtos.Create(
        "assignment-idempotent",
        "数学",
        title,
        "完成10道口算",
        "",
        "今天",
        "SCHOOL",
        "MATH",
        "NORMAL",
        null,
        "Asia/Shanghai",
        "NOT_STARTED",
        "测试",
        "老师原文",
        20,
        0L,
        0L,
        0L,
        "");
  }
}
