package com.xiaoban.homework.practice;

import com.xiaoban.homework.common.ApiExceptions;
import com.xiaoban.homework.student.StudentEntity;
import org.springframework.stereotype.Component;

@Component
public class PracticeAudiencePolicy {
  public void requireFreshStartAllowed(StudentEntity student, PracticePaperEntity paper) {
    String studentGrade = gradeCode(student.grade);
    if (!paper.grade.equals(studentGrade)) {
      throw new ApiExceptions.Conflict(
          "套卷年级与当前学生不匹配：学生=" + student.grade + "，套卷=" + paper.grade);
    }

    if (!"ALL".equals(paper.semester)) {
      String studentSemester = semesterCode(student.semester);
      if (!paper.semester.equals(studentSemester)) {
        throw new ApiExceptions.Conflict(
            "套卷学期与当前学生不匹配：学生=" + student.semester + "，套卷=" + paper.semester);
      }
    }
  }

  String gradeCode(String value) {
    if (value == null) return "";
    if (value.contains("一年级") || value.startsWith("一（") || value.equalsIgnoreCase("G1")) return "G1";
    if (value.contains("二年级") || value.startsWith("二（") || value.equalsIgnoreCase("G2")) return "G2";
    if (value.contains("三年级") || value.startsWith("三（") || value.equalsIgnoreCase("G3")) return "G3";
    if (value.contains("四年级") || value.startsWith("四（") || value.equalsIgnoreCase("G4")) return "G4";
    if (value.contains("五年级") || value.startsWith("五（") || value.equalsIgnoreCase("G5")) return "G5";
    if (value.contains("六年级") || value.startsWith("六（") || value.equalsIgnoreCase("G6")) return "G6";
    return "";
  }

  String semesterCode(String value) {
    if (value == null) return "";
    String normalized = value.trim().toUpperCase();
    if (normalized.equals("S1") || normalized.contains("上学期") || normalized.contains("第一学期")
        || normalized.contains("秋")) return "S1";
    if (normalized.equals("S2") || normalized.contains("下学期") || normalized.contains("第二学期")
        || normalized.contains("春")) return "S2";
    return "";
  }
}
