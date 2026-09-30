package com.xiaoban.homework.organizer;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
public class HomeworkOrganizerService {
  private static final Logger log = LoggerFactory.getLogger(HomeworkOrganizerService.class);
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

    List<HomeworkOrganizerDtos.Candidate> assignments = model
        .organize(student, request.sourceLabel(), request.text())
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI整理暂时不可用"));
    return new HomeworkOrganizerDtos.Response(assignments, "AI");
  }

  public HomeworkOrganizerDtos.ImageResponse organizeImage(UUID familyId, String studentId,
      HomeworkOrganizerDtos.ImageRequest request) {
    StudentEntity student = students.findById(studentId)
        .orElseThrow(() -> new ApiExceptions.NotFound("孩子不存在"));
    if (!familyId.equals(student.familyId)) throw new ApiExceptions.NotFound("孩子不存在");
    String imageDataUrl = HomeworkImageInput.dataUrl(request);
    if (!model.imageAvailable()) throw new ApiExceptions.ServiceUnavailable("AI图片解析暂未配置，请使用识别图片文字");
    var result = model.organizeImage(student, request.sourceLabel(), imageDataUrl, request.text())
        .orElseThrow(() -> new ApiExceptions.ServiceUnavailable("AI图片解析失败，请确认模型支持图片，或点击识别图片文字"));
    log.info("homework_import image_parsed studentId={} assignments={}", studentId, result.assignments().size());
    return result;
  }
}
