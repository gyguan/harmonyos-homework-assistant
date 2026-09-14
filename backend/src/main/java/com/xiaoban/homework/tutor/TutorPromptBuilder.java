package com.xiaoban.homework.tutor;

import com.xiaoban.homework.assignment.AssignmentEntity;
import com.xiaoban.homework.student.StudentEntity;
import java.util.List;

public final class TutorPromptBuilder {
  private TutorPromptBuilder() {}

  public static String instructions(boolean guidanceFirst, boolean directAnswerAllowed) {
    String answerRule = directAnswerAllowed
        ? "可以在学生已经尝试后解释完整解法，但优先检查理解，不要只给最终答案。"
        : "不要直接给出可抄写的完整答案或作文成品；应通过提示、分步问题、示例和检查理解来帮助学生自己完成。";
    String guidanceRule = guidanceFirst
        ? "每次优先给一个短提示或追问学生已经做到哪一步，再逐步增加帮助。"
        : "根据学生问题给出简短、分步骤、年龄适合的辅导。";
    return "你是“小伴”，面向中国小学生的家庭作业辅导助手。" + guidanceRule + answerRule
        + "语言要简短、鼓励、具体，默认使用中文。不要索取姓名、地址、学校、联系方式等不必要的个人信息。"
        + "遇到危险、自伤、欺凌、成人内容或需要现实世界紧急帮助的问题，不继续作业解题，应建议立即告诉家长/老师等可信成年人；有紧急危险时建议联系当地紧急服务。"
        + "只围绕当前作业和学习提供帮助，不假装已经看到了未提供的图片、附件或老师要求。";
  }

  public static String input(StudentEntity student, AssignmentEntity assignment, List<TutorMessageEntity> history, String question) {
    StringBuilder value = new StringBuilder();
    value.append("学生：").append(student.grade).append("，").append(student.className).append("。\n");
    value.append("教材：").append(student.textbookSummary == null ? "" : student.textbookSummary).append("。\n");
    value.append("当前作业：[").append(assignment.subject).append("] ").append(assignment.title).append("。\n");
    value.append("老师要求：").append(assignment.instruction).append("。\n");
    value.append("教材定位：").append(assignment.textbookRef).append("。\n");
    if (!history.isEmpty()) {
      value.append("已有对话：\n");
      int start = Math.max(0, history.size() - 12);
      for (int i = start; i < history.size(); i++) {
        TutorMessageEntity message = history.get(i);
        value.append("USER".equals(message.role) ? "学生：" : "小伴：").append(message.content).append("\n");
      }
    }
    value.append("学生现在问：").append(question);
    return value.toString();
  }
}
