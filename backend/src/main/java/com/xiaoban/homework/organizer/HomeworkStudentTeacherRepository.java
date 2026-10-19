package com.xiaoban.homework.organizer;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeworkStudentTeacherRepository extends JpaRepository<HomeworkStudentTeacherEntity, UUID> {
  List<HomeworkStudentTeacherEntity> findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(UUID familyId, String studentId);
  Optional<HomeworkStudentTeacherEntity> findByFamilyIdAndStudentIdAndTeacherNameAndSubject(
      UUID familyId, String studentId, String teacherName, String subject);
}
