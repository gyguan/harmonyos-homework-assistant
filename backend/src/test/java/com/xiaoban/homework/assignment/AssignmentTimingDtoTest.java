package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;

class AssignmentTimingDtoTest {
  @Test
  void responseCarriesPlannedActualTimingAndReviewNote() {
    AssignmentEntity entity = new AssignmentEntity();
    entity.id = "a-1";
    entity.studentId = "student-1";
    entity.assignmentType = "SCHOOL";
    entity.subjectCode = "MATH";
    entity.contentType = "NORMAL";
    entity.subject = "数学";
    entity.title = "口算 20 题";
    entity.instruction = "独立完成";
    entity.textbookRef = "数学三年级";
    entity.taskDate = LocalDate.of(2026, 10, 13);
    entity.status = "NEEDS_REWORK";
    entity.sourceLabel = "test";
    entity.sourceExcerpt = "test";
    entity.expectedMinutes = 20;
    entity.startedAtEpochMs = 1_000L;
    entity.finishedAtEpochMs = 901_000L;
    entity.elapsedSeconds = 900L;
    entity.reviewNote = "第 3 题再检查一下计算过程";
    entity.version = 3L;

    AssignmentDtos.Response response = AssignmentDtos.Response.from(entity);

    assertEquals(20, response.expectedMinutes());
    assertEquals(1_000L, response.startedAtEpochMs());
    assertEquals(901_000L, response.finishedAtEpochMs());
    assertEquals(900L, response.elapsedSeconds());
    assertEquals("第 3 题再检查一下计算过程", response.reviewNote());
    assertEquals(3L, response.version());
  }
}
