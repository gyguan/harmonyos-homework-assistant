package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.storage.FileTransactionCoordinator;
import com.xiaoban.homework.student.StudentService;
import com.xiaoban.homework.submission.SubmissionPhotoRepository;
import com.xiaoban.homework.submission.SubmissionRepository;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AssignmentServiceInitialStatusTest {
  @Test
  void createRejectsNonInitialStatus() {
    AssignmentRepository repository = mock(AssignmentRepository.class);
    StudentService students = mock(StudentService.class);
    when(repository.findById("assignment-invalid-status")).thenReturn(Optional.empty());

    AssignmentService service = new AssignmentService(
        repository,
        students,
        mock(SubmissionRepository.class),
        mock(SubmissionPhotoRepository.class),
        mock(AssignmentResourceRepository.class),
        mock(FileTransactionCoordinator.class));

    AssignmentDtos.Create input = new AssignmentDtos.Create(
        "assignment-invalid-status",
        "数学",
        "非法状态测试",
        "完成练习",
        "",
        "今天",
        "SCHOOL",
        "MATH",
        "NORMAL",
        null,
        "Asia/Shanghai",
        "COMPLETED",
        "测试",
        "",
        20,
        0L,
        0L,
        0L,
        "");

    assertThrows(ApiExceptions.BadRequest.class,
        () -> service.create(UUID.randomUUID(), "student-1", input));
  }
}
