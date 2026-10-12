package com.xiaoban.homework.organizer;

import com.xiaoban.homework.student.StudentEntity;
import java.util.List;
import java.util.Optional;

public interface HomeworkOrganizerModelClient {
  boolean available();
  Optional<List<HomeworkOrganizerDtos.Candidate>> organize(StudentEntity student, String sourceLabel, String text);

  default Optional<List<HomeworkOrganizerDtos.Candidate>> organize(StudentEntity student, String sourceLabel,
      String text, List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments) {
    return organize(student, sourceLabel, text);
  }

  default Optional<List<HomeworkOrganizerDtos.Candidate>> reviewDuplicates(
      List<HomeworkOrganizerDtos.Candidate> candidates,
      List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments,
      String sourceText) {
    return Optional.empty();
  }

  boolean imageAvailable();

  Optional<HomeworkOrganizerDtos.ImageResponse> organizeImage(StudentEntity student, String sourceLabel,
      String imageDataUrl, String text);

  default Optional<HomeworkOrganizerDtos.ImageResponse> organizeImage(StudentEntity student, String sourceLabel,
      String imageDataUrl, String text, List<HomeworkOrganizerDtos.ExistingAssignment> existingAssignments) {
    return organizeImage(student, sourceLabel, imageDataUrl, text);
  }
}
