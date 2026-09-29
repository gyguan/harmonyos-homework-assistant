package com.xiaoban.homework.scheduledassignment;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.EnumSet;
import java.util.Set;

final class ScheduledAssignmentSchedule {
  static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Shanghai");

  private ScheduledAssignmentSchedule() {}

  static Instant nextFire(ScheduledAssignmentPlanEntity plan, Instant after) {
    ZoneId zone = zone(plan.timezone);
    LocalDate cursor = after.atZone(zone).toLocalDate();
    if (cursor.isBefore(plan.startDate)) cursor = plan.startDate;
    for (int i = 0; i < 3660; i++) {
      LocalDate date = cursor.plusDays(i);
      if (plan.endDate != null && date.isAfter(plan.endDate)) return null;
      Instant candidate = fireAt(plan, date);
      if (candidate != null && candidate.isAfter(after)) return candidate;
    }
    return null;
  }

  static Instant fireAt(ScheduledAssignmentPlanEntity plan, LocalDate date) {
    if (!eligibleDate(plan, date)) return null;
    return LocalDateTime.of(date, plan.scheduleTime).atZone(zone(plan.timezone)).toInstant();
  }

  static boolean eligibleDate(ScheduledAssignmentPlanEntity plan, LocalDate date) {
    if (date.isBefore(plan.startDate)) return false;
    if (plan.endDate != null && date.isAfter(plan.endDate)) return false;
    if ("ONCE".equals(plan.scheduleType)) return date.equals(plan.startDate);
    if ("DAILY".equals(plan.scheduleType)) return true;
    if ("WEEKDAYS".equals(plan.scheduleType)) {
      return date.getDayOfWeek() != DayOfWeek.SATURDAY &&
          date.getDayOfWeek() != DayOfWeek.SUNDAY;
    }
    if ("WEEKLY".equals(plan.scheduleType)) {
      return weekdaySet(plan.weekdays).contains(date.getDayOfWeek());
    }
    return false;
  }

  static ZoneId zone(String value) {
    return ZoneId.of(value);
  }

  private static Set<DayOfWeek> weekdaySet(String value) {
    Set<DayOfWeek> result = EnumSet.noneOf(DayOfWeek.class);
    if (value == null || value.isBlank()) return result;
    for (String raw : value.split(",")) result.add(DayOfWeek.valueOf(raw));
    return result;
  }
}
