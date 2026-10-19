package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeworkOrganizerAiSnapshotService {
  private final HomeworkOrganizerAiSnapshotRepository repository;
  private final StudentRepository students;

  public HomeworkOrganizerAiSnapshotService(HomeworkOrganizerAiSnapshotRepository repository,
      StudentRepository students) {
    this.repository = repository;
    this.students = students;
  }

  public record Candidate(String candidateId, String teacherName, String subject, String title,
      String instruction, String textbookRef, String taskDate, int expectedMinutes,
      String sourceExcerpt) {
    static Candidate from(HomeworkOrganizerAiSnapshotEntity e) {
      return new Candidate(e.candidateId, e.teacherName, e.subject, e.title, e.instruction,
          e.textbookRef, e.taskDate, e.expectedMinutes, e.sourceExcerpt);
    }
  }

  private void requireOwned(UUID familyId, String studentId) {
    var student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
  }

  @Transactional(readOnly = true)
  public List<Candidate> list(UUID familyId, String studentId, String batchId) {
    requireOwned(familyId, studentId);
    return repository.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        familyId, studentId, batchId).stream().map(Candidate::from).toList();
  }

  @Transactional
  public void capture(UUID familyId, String studentId, String importId, String teacherName,
      List<HomeworkOrganizerDtos.Candidate> candidates) {
    if (importId == null || importId.isBlank()) return; // legacy callers
    requireOwned(familyId, studentId);
    if (!importId.matches("[A-Za-z0-9_-]{1,140}")) {
      throw new ApiExceptions.BadRequest("导入批次标识不合法");
    }
    if (candidates == null || candidates.size() > 30) {
      throw new ApiExceptions.BadRequest("AI 原始作业数量不合法");
    }
    var existing = repository.findByFamilyIdAndStudentIdAndBatchIdOrderByCandidateIdAsc(
        familyId, studentId, importId);
    if (!existing.isEmpty()) {
      // Retried requests are immutable: do not replace the first AI evidence with a
      // different model response. The client may retry with a new importId instead.
      if (existing.size() != candidates.size()) {
        throw new ApiExceptions.BadRequest("导入批次已存在不同版本，请重新整理");
      }
      for (int i = 0; i < candidates.size(); i++) {
        HomeworkOrganizerDtos.Candidate candidate = candidates.get(i);
        // Query order is lexicographic; compare by candidate ID rather than row index.
        String id = "ai-" + importId + "-" + (i + 1);
        var match = existing.stream().filter(row -> row.candidateId.equals(id)).findFirst().orElse(null);
        if (match == null || !match.title.equals(clean(candidate.title(), 400))
            || !match.subject.equals(clean(candidate.subject(), 20))
            || !match.teacherName.equals(clean(teacherName, 80))
            || !match.instruction.equals(clean(candidate.instruction(), 1500))
            || !match.textbookRef.equals(clean(candidate.textbookRef(), 100))
            || !match.taskDate.equals(date(candidate.taskDate()))
            || match.expectedMinutes != Math.max(5, Math.min(120, candidate.expectedMinutes()))
            || !match.sourceExcerpt.equals(clean(candidate.sourceExcerpt(), 500))) {
          throw new ApiExceptions.BadRequest("导入批次已存在不同版本，请重新整理");
        }
      }
      return;
    }
    Instant now = Instant.now();
    var rows = new ArrayList<HomeworkOrganizerAiSnapshotEntity>();
    for (int i = 0; i < candidates.size(); i++) {
      var candidate = candidates.get(i);
      var row = new HomeworkOrganizerAiSnapshotEntity();
      row.id = UUID.randomUUID();
      row.familyId = familyId;
      row.studentId = studentId;
      row.batchId = importId;
      row.candidateId = "ai-" + importId + "-" + (i + 1);
      row.teacherName = clean(teacherName, 80);
      row.subject = clean(candidate.subject(), 20);
      row.title = clean(candidate.title(), 400);
      row.instruction = clean(candidate.instruction(), 1500);
      row.textbookRef = clean(candidate.textbookRef(), 100);
      row.taskDate = date(candidate.taskDate());
      row.expectedMinutes = Math.max(5, Math.min(120, candidate.expectedMinutes()));
      row.sourceExcerpt = clean(candidate.sourceExcerpt(), 500);
      row.createdAt = now;
      rows.add(row);
    }
    repository.saveAll(rows);
  }

  private static String clean(String v, int max) {
    String text = v == null ? "" : v.trim();
    return text.length() > max ? text.substring(0, max) : text;
  }

  private static String date(String input) {
    try {
      return LocalDate.parse(input).toString();
    } catch (Exception ex) {
      return LocalDate.now(ZoneId.of("Asia/Shanghai")).toString();
    }
  }
}
