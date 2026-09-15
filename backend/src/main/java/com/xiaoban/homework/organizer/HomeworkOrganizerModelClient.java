package com.xiaoban.homework.organizer;

import com.xiaoban.homework.student.StudentEntity;
import java.util.List;
import java.util.Optional;

public interface HomeworkOrganizerModelClient {
  boolean available();
  Optional<List<HomeworkOrganizerDtos.Candidate>> organize(StudentEntity student, String sourceLabel, String text);
}
