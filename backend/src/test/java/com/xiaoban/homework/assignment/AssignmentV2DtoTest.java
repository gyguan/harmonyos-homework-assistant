package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class AssignmentV2DtoTest {
  @Test
  void responseCarriesTaskDateAndV2Fields() {
    AssignmentEntity entity = new AssignmentEntity();
    entity.id = "a-v2-1";
    entity.studentId = "student-1";
    entity.assignmentType = "SCHOOL";
    entity.subjectCode = "MATH";
    entity.contentType = "AUDIO_IMAGE";
    entity.subject = "数学";
    entity.title = "口算 20 题";
    entity.instruction = "独立完成";
    entity.textbookRef = "数学三年级";
    entity.taskDate = LocalDate.of(2026, 10, 13);
    entity.status = "NOT_STARTED";
    entity.sourceLabel = "老师消息";
    entity.sourceExcerpt = "完成口算 20 题";
    entity.expectedMinutes = 20;
    entity.reviewNote = "";
    entity.version = 2L;

    AssignmentDtos.Response response = AssignmentDtos.Response.from(entity);

    assertEquals("SCHOOL", response.assignmentType());
    assertEquals("MATH", response.subjectCode());
    assertEquals("AUDIO_IMAGE", response.contentType());
    assertEquals("2026-10-13", response.taskDate());
    assertEquals("数学", response.subject());
    assertEquals(2L, response.version());
  }
}
