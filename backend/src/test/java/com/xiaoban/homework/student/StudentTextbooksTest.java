package com.xiaoban.homework.student;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class StudentTextbooksTest {
  @Test
  void parsesLegacyMultiSubjectSummary() {
    StudentTextbooks textbooks =
        StudentTextbooks.parseLegacy("语文部编版 · 数学北师大版 · 英语沪教版");

    assertEquals("部编版", textbooks.chinese());
    assertEquals("北师大版", textbooks.math());
    assertEquals("沪教版", textbooks.english());
    assertEquals("语文=部编版；数学=北师大版；英语=沪教版", textbooks.summary());
  }

  @Test
  void structuredFieldsOverrideLegacyPerSubjectWithoutDroppingOtherSubjects() {
    StudentEntity student = new StudentEntity();
    student.chineseTextbook = "统编版";
    student.mathTextbook = "";
    student.englishTextbook = "";
    student.otherTextbooks = "";
    student.textbookSummary = "语文=部编版；数学=北师大版；英语=人教版";

    StudentTextbooks textbooks = StudentTextbooks.from(student);

    assertEquals("统编版", textbooks.chinese());
    assertEquals("北师大版", textbooks.math());
    assertEquals("人教版", textbooks.english());
  }

  @Test
  void validatesOtherTextbookFormat() {
    assertTrue(StudentTextbooks.validOthers(""));
    assertTrue(StudentTextbooks.validOthers("科学=教科版；道德与法治=人教版"));
    assertFalse(StudentTextbooks.validOthers("科学教科版"));
    assertFalse(StudentTextbooks.validOthers("科学="));
  }
}
