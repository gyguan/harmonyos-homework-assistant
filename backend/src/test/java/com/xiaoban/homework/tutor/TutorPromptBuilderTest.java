package com.xiaoban.homework.tutor;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class TutorPromptBuilderTest {
  @Test
  void guidanceFirstPolicyBlocksCopyableAnswersByDefault() {
    String prompt = TutorPromptBuilder.instructions(true, false);
    assertTrue(prompt.contains("不要直接给出"));
    assertTrue(prompt.contains("提示"));
    assertTrue(prompt.contains("个人信息"));
    assertTrue(prompt.contains("可信成年人"));
  }
}
