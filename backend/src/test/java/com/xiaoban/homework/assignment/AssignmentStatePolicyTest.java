package com.xiaoban.homework.assignment;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;

class AssignmentStatePolicyTest {
  @Test void allowsNormalLifecycle() {
    assertThat(AssignmentStatePolicy.canTransition("NOT_STARTED", "IN_PROGRESS")).isTrue();
    assertThat(AssignmentStatePolicy.canTransition("IN_PROGRESS", "READY_TO_SUBMIT")).isTrue();
    assertThat(AssignmentStatePolicy.canTransition("READY_TO_SUBMIT", "SUBMITTED")).isTrue();
    assertThat(AssignmentStatePolicy.canTransition("SUBMITTED", "COMPLETED")).isTrue();
  }

  @Test void rejectsIllegalJump() {
    assertThat(AssignmentStatePolicy.canTransition("NOT_STARTED", "COMPLETED")).isFalse();
  }
}
