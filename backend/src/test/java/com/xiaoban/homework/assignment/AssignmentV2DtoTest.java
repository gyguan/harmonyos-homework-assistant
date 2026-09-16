package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Instant;
import org.junit.jupiter.api.Test;

class AssignmentV2DtoTest {
  @Test
  void responseCarriesV2AndLegacyCompatibilityFields() {
    AssignmentEntity entity = new AssignmentEntity();
    entity.id = "a-v2-1";
    entity.studentId = "student-1";
    entity.assignmentType = "SCHOOL";
    entity.subjectCode = "MATH";
    entity.subject = "数学";
    entity.title = "口算 20 题";
    entity.instruction = "独立完成";
    entity.textbookRef = "数学三年级";
    entity.dueAt = Instant.ofEpochMilli(1_800_000L);
    entity.dueTimezone = "Asia/Shanghai";
    entity.dueText = "今晚 20:30";
    entity.status = "NOT_STARTED";
    entity.sourceLabel = "老师消息";
    entity.sourceExcerpt = "完成口算 20 题";
    entity.expectedMinutes = 20;
    entity.reviewNote = "";
    entity.version = 2L;

    AssignmentDtos.Response response = AssignmentDtos.Response.from(entity);

    assertEquals("SCHOOL", response.assignmentType());
    assertEquals("MATH", response.subjectCode());
    assertEquals(1_800_000L, response.dueAtEpochMs());
    assertEquals("Asia/Shanghai", response.dueTimezone());
    assertEquals("数学", response.subject());
    assertEquals("今晚 20:30", response.dueText());
    assertEquals(2L, response.version());
  }
}
