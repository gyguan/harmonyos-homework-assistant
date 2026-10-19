package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentRepository;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeworkStudentTeacherService {
  private final HomeworkStudentTeacherRepository repository;
  private final StudentRepository students;

  public HomeworkStudentTeacherService(HomeworkStudentTeacherRepository repository,
      StudentRepository students) {
    this.repository = repository;
    this.students = students;
  }

  public record TeacherInput(@NotBlank @Size(max = 80) String teacherName,
      @NotBlank @Size(max = 20) String subject) {}
  public record TeacherResult(UUID id, String teacherName, String subject, boolean enabled) {
    static TeacherResult from(HomeworkStudentTeacherEntity value) {
      return new TeacherResult(value.id, value.teacherName, value.subject, value.enabled);
    }
  }

  void requireOwned(UUID familyId, String studentId) {
    var student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
  }

  @Transactional(readOnly = true)
  public List<TeacherResult> list(UUID familyId, String studentId) {
    requireOwned(familyId, studentId);
    return repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId)
        .stream().filter(t -> t.enabled).map(TeacherResult::from).toList();
  }

  @Transactional
  public TeacherResult register(UUID familyId, String studentId, TeacherInput input) {
    requireOwned(familyId, studentId);
    String name = input.teacherName().trim();
    String subject = input.subject().trim();
    if (name.length() < 2 || name.equals("未知") || name.equals("未识别")) {
      throw new ApiExceptions.BadRequest("请填写老师姓名或称呼");
    }
    if (subject.isEmpty()) throw new ApiExceptions.BadRequest("请选择老师的学科");
    var row = repository.findByFamilyIdAndStudentIdAndTeacherNameAndSubject(
        familyId, studentId, name, subject).orElse(null);
    if (row == null) {
      if (repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId).size() >= 50) {
        throw new ApiExceptions.BadRequest("当前学生已保存过多老师，请先整理历史记录");
      }
      row = new HomeworkStudentTeacherEntity();
      row.id = UUID.randomUUID();
      row.familyId = familyId;
      row.studentId = studentId;
      row.teacherName = name;
      row.subject = subject;
      row.createdAt = Instant.now();
    }
    row.enabled = true;
    row.updatedAt = Instant.now();
    return TeacherResult.from(repository.save(row));
  }

  @Transactional(readOnly = true)
  public String verifiedTeacher(UUID familyId, String studentId, String selectedName) {
    requireOwned(familyId, studentId);
    if (selectedName == null || selectedName.isBlank()) return "";
    String name = selectedName.trim();
    boolean registered = repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(familyId, studentId)
        .stream().anyMatch(t -> t.enabled && t.teacherName.equals(name));
    if (!registered) throw new ApiExceptions.BadRequest("所选老师未绑定当前学生，请先保存老师");
    return name;
  }
}
