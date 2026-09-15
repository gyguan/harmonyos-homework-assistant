package com.xiaoban.homework.assignment;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class AssignmentTimingDtoTest {
  @Test
  void responseCarriesPlannedAndActualTiming() {
    AssignmentEntity entity = new AssignmentEntity();
    entity.id = "a-1";
    entity.studentId = "student-1";
    entity.subject = "数学";
    entity.title = "口算 20 题";
    entity.instruction = "独立完成";
    entity.textbookRef = "数学三年级";
    entity.dueText = "今晚";
    entity.status = "READY_TO_SUBMIT";
    entity.sourceLabel = "test";
    entity.sourceExcerpt = "test";
    entity.expectedMinutes = 20;
    entity.startedAtEpochMs = 1_000L;
    entity.finishedAtEpochMs = 901_000L;
    entity.elapsedSeconds = 900L;
    entity.version = 3L;

    AssignmentDtos.Response response = AssignmentDtos.Response.from(entity);

    assertEquals(20, response.expectedMinutes());
    assertEquals(1_000L, response.startedAtEpochMs());
    assertEquals(901_000L, response.finishedAtEpochMs());
    assertEquals(900L, response.elapsedSeconds());
    assertEquals(3L, response.version());
  }
}
