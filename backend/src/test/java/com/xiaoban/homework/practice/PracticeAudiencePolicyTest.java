package com.xiaoban.homework.practice;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class PracticeAudiencePolicyTest {
  private final PracticeAudiencePolicy policy = new PracticeAudiencePolicy();

  @Test
  void normalizesGradeLabels() {
    assertEquals("G2", policy.gradeCode("二年级"));
    assertEquals("G2", policy.gradeCode("二（2）班"));
    assertEquals("G2", policy.gradeCode("G2"));
  }

  @Test
  void normalizesSemesterLabels() {
    assertEquals("S1", policy.semesterCode("上学期"));
    assertEquals("S1", policy.semesterCode("2026秋"));
    assertEquals("S2", policy.semesterCode("下学期"));
    assertEquals("S2", policy.semesterCode("2027春"));
  }
}
