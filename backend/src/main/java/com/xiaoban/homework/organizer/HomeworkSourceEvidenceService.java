package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentRepository;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.stream.IntStream;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

@Service
public class HomeworkSourceEvidenceService {
  private final HomeworkSourceEvidenceRepository repository;
  private final StudentRepository students;
  private final HomeworkOrganizerAiSnapshotService snapshots;
  private final JsonMapper json;
  public HomeworkSourceEvidenceService(HomeworkSourceEvidenceRepository repository, StudentRepository students,
      HomeworkOrganizerAiSnapshotService snapshots, JsonMapper json) {
    this.repository = repository; this.students = students; this.snapshots = snapshots; this.json = json;
  }
  public record Mapping(String candidateId, List<String> sourceBlockIds) {}
  public record Evidence(HomeworkSourceDocument sourceDocument, List<Mapping> mappings,
      List<HomeworkOrganizerDtos.QualityFlag> qualityFlags, boolean needsReview) {}
  private void owned(UUID family, String student) {
    var found = students.findById(student).orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!family.equals(found.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
  }
  @Transactional(readOnly = true)
  public Evidence get(UUID family, String student, String batch) {
    owned(family, student);
    var row = repository.findByFamilyIdAndStudentIdAndBatchId(family, student, batch)
        .orElseThrow(() -> new ApiExceptions.NotFound("来源证据不存在"));
    return json.readValue(row.evidenceJson, Evidence.class);
  }
  @Transactional
  public void capture(UUID family, String student, String batch, String teacher,
      List<HomeworkOrganizerDtos.Candidate> items, HomeworkSourceDocument document,
      List<HomeworkOrganizerDtos.QualityFlag> flags, boolean needsReview) {
    if (batch == null || batch.isBlank()) return;
    owned(family, student);
    if (!batch.matches("[A-Za-z0-9_-]{1,140}")) throw new ApiExceptions.BadRequest("导入批次标识不合法");
    var mappings = IntStream.range(0, items.size()).mapToObj(i ->
        new Mapping("ai-" + batch + "-" + (i + 1), items.get(i).sourceBlockIds())).toList();
    var evidence = new Evidence(document, mappings, flags, needsReview);
    String encoded = json.writeValueAsString(evidence);
    var existing = repository.findByFamilyIdAndStudentIdAndBatchId(family, student, batch);
    if (existing.isPresent()) {
      if (!json.readValue(existing.get().evidenceJson, Evidence.class).equals(evidence))
        throw new ApiExceptions.BadRequest("导入批次已存在不同来源，请重新整理");
    } else {
      var row = new HomeworkSourceEvidenceEntity();
      row.id = UUID.randomUUID(); row.familyId = family; row.studentId = student;
      row.batchId = batch; row.evidenceJson = encoded; row.createdAt = Instant.now();
      repository.save(row);
    }
    // Both first draft and independent evidence commit/rollback together.
    snapshots.capture(family, student, batch, teacher, items);
  }
}
