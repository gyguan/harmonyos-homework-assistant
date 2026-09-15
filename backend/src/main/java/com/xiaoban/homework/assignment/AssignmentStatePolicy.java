package com.xiaoban.homework.assignment;

import java.util.Map;
import java.util.Set;

public final class AssignmentStatePolicy {
  private AssignmentStatePolicy() {}
  private static final Map<String, Set<String>> NEXT = Map.of(
      "NOT_STARTED", Set.of("IN_PROGRESS", "OVERDUE"),
      "IN_PROGRESS", Set.of("PAUSED", "READY_TO_SUBMIT", "OVERDUE"),
      "PAUSED", Set.of("IN_PROGRESS", "OVERDUE"),
      "READY_TO_SUBMIT", Set.of("SUBMITTED", "IN_PROGRESS"),
      "SUBMITTED", Set.of("COMPLETED", "NEEDS_REWORK"),
      "NEEDS_REWORK", Set.of("IN_PROGRESS", "READY_TO_SUBMIT"),
      "OVERDUE", Set.of("IN_PROGRESS", "READY_TO_SUBMIT"),
      "COMPLETED", Set.of()
  );

  public static boolean canTransition(String from, String to) {
    return from.equals(to) || NEXT.getOrDefault(from, Set.of()).contains(to);
  }
}
