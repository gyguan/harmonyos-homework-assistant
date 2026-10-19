package com.xiaoban.homework.organizer;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.xiaoban.homework.student.StudentEntity;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class HomeworkOrganizerRuleServiceTest {
  private static HomeworkOrganizerRuleEntity shorthand(String code, String term,
      String meaning, int priority) {
    var item = new HomeworkOrganizerRuleEntity();
    item.code = code;
    item.ruleType = "SHORTHAND";
    item.scope = "GLOBAL";
    item.subject = "英语";
    item.triggerText = term;
    item.meaning = meaning;
    item.shortTitle = meaning;
    item.priority = priority;
    item.enabled = true;
    return item;
  }

  @Test void databasePriorityWinsAndDisabledRecordsAreNotLoaded() {
    var repository = mock(HomeworkOrganizerRuleRepository.class);
    var high = shorthand("high", "听读U*", "优先解释", 100);
    var low = shorthand("low", "听读U*", "过时解释", 50);
    var another = shorthand("another", "一起作业", "平台任务", 80);
    when(repository.findByEnabledTrueOrderByPriorityDescCodeAsc())
        .thenReturn(List.of(high, another, low));
    var snapshot = new HomeworkOrganizerRuleService(repository).snapshot(null, "", "");
    assertEquals(2, snapshot.shorthand().size());
    assertTrue(snapshot.encodedShorthand().contains("优先解释"));
    assertFalse(snapshot.encodedShorthand().contains("过时解释"));
    verify(repository).findByEnabledTrueOrderByPriorityDescCodeAsc();
  }

  @Test void databaseTemplatingSupportsDirectEnableDisableWithoutJavaFallback() {
    var repository = mock(HomeworkOrganizerRuleRepository.class);
    var template = new HomeworkOrganizerRuleEntity();
    template.code = "format";
    template.ruleType = "PROMPT";
    template.scope = "GLOBAL";
    template.templateKey = "BLACKBOARD";
    template.promptText = "从数据库加载的黑板模板";
    when(repository.findByEnabledTrueOrderByPriorityDescCodeAsc()).thenReturn(List.of(template));
    var service = new HomeworkOrganizerRuleService(repository);
    assertEquals("从数据库加载的黑板模板", service.snapshot(null, "", "").template("BLACKBOARD"));
    when(repository.findByEnabledTrueOrderByPriorityDescCodeAsc()).thenReturn(List.of());
    assertEquals("", service.snapshot(null, "", "").template("BLACKBOARD"),
        "Disabling a row must not silently re-enable a Java fallback");
    assertEquals("", service.snapshot(null, "", "").encodedShorthand());
  }

  @Test void privateRuleCannotLeakToDifferentStudentOrAmbiguousTeacher() {
    var repository = mock(HomeworkOrganizerRuleRepository.class);
    var family = UUID.randomUUID();
    var rule = shorthand("private", "国*", "本学生专用国学规则", 300);
    rule.scope = "STUDENT";
    rule.familyId = family;
    rule.studentId = "child-1";
    rule.subject = "语文";
    when(repository.findByEnabledTrueOrderByPriorityDescCodeAsc()).thenReturn(List.of(rule));
    var student = new StudentEntity() {};
    student.id = "child-1";
    student.familyId = family;
    var other = new StudentEntity() {};
    other.id = "child-2";
    other.familyId = family;
    var service = new HomeworkOrganizerRuleService(repository);
    assertEquals(1, service.snapshot(student, "", "语文：朗读国13").shorthand().size());
    assertTrue(service.snapshot(student, "", "数学：口算20题").shorthand().isEmpty());
    assertTrue(service.snapshot(student, "", "王老师：语文朗读国13").shorthand().isEmpty());
    assertTrue(service.snapshot(other, "", "语文：朗读国13").shorthand().isEmpty());
  }
}
