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

  public HomeworkOrganizerService(StudentRepository students, HomeworkOrganizerModelClient model) {
    this.students = students;
    this.model = model;
  }

  public HomeworkOrganizerDtos.Response organize(UUID familyId, String studentId, HomeworkOrganizerDtos.Request request) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    if (!model.available()) throw new ApiExceptions.ServiceUnavailable("AI整理暂未配置");

    List<HomeworkOrganizerDtos.Candidate> organized = model
        .organize(student, request.sourceLabel(), request.text())
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI整理暂时不可用"));
    List<HomeworkOrganizerDtos.Candidate> normalized =
        normalizeDefaultTaskDates(organized, request.text());
    log.info("homework_import organized studentId={} assignments={}", studentId, normalized.size());
    return new HomeworkOrganizerDtos.Response(normalized, "AI");
  }

  public HomeworkOrganizerDtos.ImageResponse organizeImage(UUID familyId, String studentId,
      HomeworkOrganizerDtos.ImageRequest request) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    String imageDataUrl = HomeworkImageInput.dataUrl(request);
    if (!model.imageAvailable()) throw new ApiExceptions.ServiceUnavailable("AI图片解析暂未配置");
    var result = model.organizeImage(
        student, request.sourceLabel(), imageDataUrl, request.text())
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI图片解析失败，请确认模型支持图片"));
    List<HomeworkOrganizerDtos.Candidate> normalized =
        normalizeDefaultTaskDates(result.assignments(), result.recognizedText());
    log.info("homework_import image_parsed studentId={} assignments={}", studentId, normalized.size());
    return new HomeworkOrganizerDtos.ImageResponse(
        normalized, result.mode(), result.recognizedText());
  }

  static List<HomeworkOrganizerDtos.Candidate> normalizeDefaultTaskDates(
      List<HomeworkOrganizerDtos.Candidate> candidates, String sourceText) {
    if (candidates == null || candidates.isEmpty()) {
      return candidates == null ? List.of() : candidates;
    }
    if (hasExplicitTaskDate(sourceText)) return candidates;

    String today = LocalDate.now(BUSINESS_ZONE).toString();
    List<HomeworkOrganizerDtos.Candidate> result = new ArrayList<>();
    for (HomeworkOrganizerDtos.Candidate candidate : candidates) {
      if (candidate == null) continue;
      result.add(new HomeworkOrganizerDtos.Candidate(
          candidate.subject(), candidate.title(), candidate.instruction(), candidate.textbookRef(),
          today, candidate.expectedMinutes(), candidate.sourceExcerpt(), candidate.confidence(),
          candidate.sameTaskGroup(), candidate.duplicateAssignmentId(), candidate.duplicateAssignmentTitle(),
          candidate.duplicateConfidence(), candidate.duplicateReason()));
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
        "(?s).*(?:完成|截止|提交|上交|日期).{0,8}\\d{1,2}[-/.]\\d{1,2}.*") ||
        text.matches("(?s).*\\d{1,2}[-/.]\\d{1,2}.{0,8}(?:完成|截止|提交|上交).*");
  }


}
