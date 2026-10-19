package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class HomeworkTeacherAttributionTest {
  @Test void explicitUniqueNamedTeacherCanBeUsedWithoutMaintainingDirectory() {
    assertEquals("王老师", HomeworkTeacherAttribution.resolve(
        "", "语文", "语文老师通知", "王老师：朗读国13"));
    assertEquals("李老师", HomeworkTeacherAttribution.resolve(
        "", "数学", "数学：李老师：", "口算20题"));
  }

  @Test void cannotInventTeacherFromSchoolSubjectOrTwoDifferentNames() {
    assertEquals("学科归属:语文", HomeworkTeacherAttribution.resolve(
        "", "语文", "家长录入文字", "语文：朗读国13"));
    assertEquals("学科归属:数学", HomeworkTeacherAttribution.resolve(
        "", "数学", "数学老师", "口算20题"));
    assertEquals("", HomeworkTeacherAttribution.explicitSourceTeacher(
        "王老师：朗读国13；李老师：抄写生字"));
    assertTrue(HomeworkTeacherAttribution.hasNamedTeachers(
        "王老师：朗读国13；李老师：抄写生字"));
    assertFalse(HomeworkTeacherAttribution.hasNamedTeachers("语文老师：朗读国13"));
  }

  @Test void subjectExperienceNeverAppliesToMixedSubjects() {
    assertTrue(HomeworkTeacherAttribution.matchesUnambiguousSubject("语文：朗读国13", "语文"));
    assertFalse(HomeworkTeacherAttribution.matchesUnambiguousSubject(
        "语文：朗读国13；数学：口算20题", "语文"));
    assertFalse(HomeworkTeacherAttribution.matchesUnambiguousSubject("听读U4", "语文"));
  }
}
