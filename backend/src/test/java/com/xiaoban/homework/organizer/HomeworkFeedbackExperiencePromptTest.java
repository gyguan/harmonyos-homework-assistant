package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.xiaoban.homework.student.StudentEntity;
import com.xiaoban.homework.student.StudentRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkFeedbackExperiencePromptTest {
  private static StudentEntity student(UUID family, String id) {
    var e = new StudentEntity() {};
    e.familyId = family;
    e.id = id;
    return e;
  }

  private static HomeworkTeacherExperienceEntity learned(String student, UUID family,
      String origin, String cue) {
    var row = new HomeworkTeacherExperienceEntity();
    row.familyId = family;
    row.studentId = student;
    row.teacherName = "学科归属:语文";
    row.subject = "语文";
    row.cue = cue;
    row.interpretation = "适用条件：语文摘抄题目中出现两个数值时；整理要求：前一个为好词的条数、后一个为好句的条数，按照本次原文动态展开任务标题";
    row.exampleSource = "摘抄：（4+2）";
    row.exampleResult = "";
    row.origin = origin;
    row.active = true;
    return row;
  }

  @Test void nextDayDifferentNumbersRetrieveGenericAiRuleByMeaningNotLiteralMatch() {
    UUID family = UUID.randomUUID();
    var repository = mock(HomeworkTeacherExperienceRepository.class);
    var student = student(family, "child1");
    var row = learned("child1", family, "FEEDBACK_AI", "摘抄");
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(row));
    var svc = new HomeworkTeacherExperienceService(repository, mock(StudentRepository.class));

    String context = svc.context(student, "家长录入文字", "今日语文：摘抄（3+1）", false);
    assertTrue(context.contains("前一个为好词的条数"), context);
    assertTrue(context.contains("title 和 instruction"), context);
    assertTrue(context.contains("变量和数量必须取本次原文的值"), context);
    assertEquals("", svc.context(student, "家长录入文字", "数学：口算20题", false));
    assertEquals("", svc.context(student, "王老师：数学作业", "王老师布置口算20题", false));
    assertEquals("", svc.context(student(family, "other-child"), "家长录入文字",
        "语文：摘抄（3+1）", false));

    row.active = false;
    assertEquals("", svc.context(student, "家长录入文字", "语文：摘抄（3+1）", false));
  }

  @Test void existingOldFeedbackAlsoIsAvailableSemanticallyWithoutMigrations() {
    UUID family = UUID.randomUUID();
    var repository = mock(HomeworkTeacherExperienceRepository.class);
    var student = student(family, "child1");
    var old = learned("child1", family, "FEEDBACK_AUTO", "摘抄：（4+2）");
    old.interpretation = "家长反馈：4+2标识4个好词、2个好句，要按本次实际数字解释";
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(old));
    var svc = new HomeworkTeacherExperienceService(repository, mock(StudentRepository.class));
    String context = svc.context(student, "家长录入文字", "语文：摘抄：（3+2）", false);
    assertTrue(context.contains("4+2标识4个好词"), context);
    assertTrue(context.contains("不得继续仅保留未展开的简写"), context);
  }

  @Test void imagePromptProvidesConditionalKnowledgeWithoutInventingImageText() {
    UUID family = UUID.randomUUID();
    var repository = mock(HomeworkTeacherExperienceRepository.class);
    var student = student(family, "child1");
    var rule = learned("child1", family, "FEEDBACK_AI", "摘抄");
    when(repository.findByFamilyIdAndStudentIdOrderByUpdatedAtDesc(family, "child1"))
        .thenReturn(List.of(rule));
    var svc = new HomeworkTeacherExperienceService(repository, mock(StudentRepository.class));
    String imageHint = svc.context(student, "黑板图片", "", true);
    assertTrue(imageHint.contains("图片里必须识别出符合的老师和线索"), imageHint);
    assertTrue(imageHint.contains("好词的条数"), imageHint);
  }
}
