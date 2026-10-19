package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
public class HomeworkOrganizerService {
  private static final Logger log = LoggerFactory.getLogger(HomeworkOrganizerService.class);
  private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");
  private final StudentRepository students;
  private final HomeworkOrganizerModelClient model;
  private final HomeworkStudentTeacherService teachers;
  private final HomeworkOrganizerAiSnapshotService snapshots;
  private final HomeworkTeacherExperienceService learnedExperiences;

  public HomeworkOrganizerService(StudentRepository students, HomeworkOrganizerModelClient model) {
    this(students, model, null, null, null);
  }

  public HomeworkOrganizerService(StudentRepository students, HomeworkOrganizerModelClient model,
      HomeworkStudentTeacherService teachers) {
    this(students, model, teachers, null, null);
  }

  public HomeworkOrganizerService(StudentRepository students, HomeworkOrganizerModelClient model,
      HomeworkStudentTeacherService teachers, HomeworkOrganizerAiSnapshotService snapshots) {
    this(students, model, teachers, snapshots, null);
  }

  @org.springframework.beans.factory.annotation.Autowired
  public HomeworkOrganizerService(StudentRepository students, HomeworkOrganizerModelClient model,
      HomeworkStudentTeacherService teachers, HomeworkOrganizerAiSnapshotService snapshots,
      HomeworkTeacherExperienceService learnedExperiences) {
    this.students = students;
    this.model = model;
    this.teachers = teachers;
    this.snapshots = snapshots;
    this.learnedExperiences = learnedExperiences;
  }

  private List<HomeworkOrganizerDtos.Candidate> applyLearnedConventions(
      StudentEntity student, String sourceLabel, String sourceText,
      List<HomeworkOrganizerDtos.Candidate> candidates) {
    return learnedExperiences == null ? candidates
        : learnedExperiences.applyConfirmedExcerptCounts(student, sourceLabel, sourceText, candidates);
  }

  private String teacherLabel(UUID familyId, String studentId, String label, String selectedTeacher) {
    if (selectedTeacher == null || selectedTeacher.isBlank()) return label;
    if (teachers == null) throw new ApiExceptions.BadRequest("老师资料尚未配置");
    String verified = teachers.verifiedTeacher(familyId, studentId, selectedTeacher);
    // Explicit verified identity is conveyed to AI separately from the untrusted original message.
    return (label == null ? "" : label) + "\n[家长已确认老师：" + verified + "]";
  }

  public HomeworkOrganizerDtos.Response organize(UUID familyId, String studentId, HomeworkOrganizerDtos.Request request) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    if (!model.available()) throw new ApiExceptions.ServiceUnavailable("AI整理暂未配置");

    List<HomeworkOrganizerDtos.Candidate> organized = model
        .organize(student, teacherLabel(familyId, studentId, request.sourceLabel(), request.teacherName()), request.text())
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI整理暂时不可用"));
    List<HomeworkOrganizerDtos.Candidate> normalized = applyLearnedConventions(
        student, request.sourceLabel(), request.text(),
        normalizeDefaultTaskDates(organized, request.text()));
    if (snapshots != null) {
      String sourcedTeacher = request.teacherName() == null || request.teacherName().isBlank()
          ? HomeworkTeacherAttribution.explicitSourceTeacher(request.text())
          : request.teacherName();
      snapshots.capture(familyId, studentId, request.importId(), sourcedTeacher, normalized);
    }
    log.info("homework_import organized studentId={} assignments={}", studentId, normalized.size());
    return new HomeworkOrganizerDtos.Response(normalized, "AI");
  }

  public HomeworkOrganizerDtos.ImageResponse organizeImage(UUID familyId, String studentId,
      HomeworkOrganizerDtos.ImageRequest request) {
    long totalStarted = System.nanoTime();
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");

    long validateStarted = System.nanoTime();
    String imageDataUrl = HomeworkImageInput.dataUrl(request);
    long validateMs = elapsedMs(validateStarted);

    if (!model.imageAvailable()) throw new ApiExceptions.ServiceUnavailable("AI图片解析暂未配置");
    long modelStarted = System.nanoTime();
    var result = model.organizeImage(
        student, teacherLabel(familyId, studentId, request.sourceLabel(), request.teacherName()), imageDataUrl, request.text())
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI图片解析失败，请确认模型支持图片"));
    long modelMs = elapsedMs(modelStarted);

    List<HomeworkOrganizerDtos.Candidate> normalized = applyLearnedConventions(
        student, request.sourceLabel(), result.recognizedText(),
        normalizeDefaultTaskDates(result.assignments(), result.recognizedText()));
    if (snapshots != null) {
      snapshots.capture(familyId, studentId, request.importId(), request.teacherName(), normalized);
    }
    log.info(
        "[AI-PERF] homework_image studentId={} base64Chars={} imageValidateMs={} modelMs={} totalMs={} assignments={} recognizedChars={}",
        studentId,
        request.imageBase64() == null ? 0 : request.imageBase64().length(),
        validateMs,
        modelMs,
        elapsedMs(totalStarted),
        normalized.size(),
        result.recognizedText() == null ? 0 : result.recognizedText().length());
    return new HomeworkOrganizerDtos.ImageResponse(
        normalized, result.mode(), result.recognizedText());
  }

  private static long elapsedMs(long started) {
    return java.util.concurrent.TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - started);
  }

  static List<HomeworkOrganizerDtos.Candidate> normalizeDefaultTaskDates(
      List<HomeworkOrganizerDtos.Candidate> candidates, String sourceText) {
    if (candidates == null || candidates.isEmpty()) {
      return candidates == null ? List.of() : candidates;
    }

    boolean keepRecognizedDate = hasExplicitTaskDate(sourceText);
    String today = LocalDate.now(BUSINESS_ZONE).toString();
    List<HomeworkOrganizerDtos.Candidate> result = new ArrayList<>();
    for (HomeworkOrganizerDtos.Candidate candidate : candidates) {
      if (candidate == null) continue;
      String taskDate = keepRecognizedDate ? candidate.taskDate() : today;
      result.add(new HomeworkOrganizerDtos.Candidate(
          candidate.subject(), candidate.title(), candidate.instruction(), candidate.textbookRef(),
          taskDate, candidate.expectedMinutes(), candidate.sourceExcerpt(), candidate.confidence(),
          "", "", "", 0.0, ""));
    }
    return result;
  }

  static boolean hasExplicitTaskDate(String sourceText) {
    if (sourceText == null || sourceText.isBlank()) return false;
    String text = sourceText.trim();
    if (text.contains("今天") || text.contains("今日") || text.contains("今晚") ||
        text.contains("明天") || text.contains("明日") || text.contains("后天")) {
      return true;
    }
    if (text.matches("(?s).*(?:周|星期)[一二三四五六日天].*")) return true;
    if (text.matches("(?s).*\\d{4}年\\d{1,2}月\\d{1,2}[日号]?.*")) return true;
    if (text.matches("(?s).*\\d{1,2}月\\d{1,2}[日号].*")) return true;
    if (text.matches("(?s).*\\d{4}[-/.]\\d{1,2}[-/.]\\d{1,2}.*")) return true;
    return text.matches(
        "(?s).*(?:截止|提交|上交|日期).{0,8}(?<!第)\\d{1,2}[-/.]\\d{1,2}(?!题).*") ||
        text.matches(
            "(?s).*(?<!第)\\d{1,2}[-/.]\\d{1,2}(?!题).{0,8}(?:截止|提交|上交|日期).*");
  }


}
