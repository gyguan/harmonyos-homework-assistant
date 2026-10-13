import { AssignmentTaskDate } from './AssignmentTaskDate';

export interface AssignmentEpochRange {
  fromEpochMs: number;
  toEpochMs: number;
}

export class AssignmentDateRange {
  static forDay(dayEpochMs: number): AssignmentEpochRange {
    let taskDate = AssignmentTaskDate.fromEpochMs(dayEpochMs);
    let dayStart = AssignmentTaskDate.toDayStartEpochMs(taskDate);
    let nextDayStart = AssignmentTaskDate.toDayStartEpochMs(AssignmentTaskDate.addDays(taskDate, 1));
    return { fromEpochMs: dayStart, toEpochMs: nextDayStart - 1 };
  }

  static today(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    return AssignmentDateRange.forDay(nowEpochMs);
  }

  static tomorrow(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    let date = AssignmentTaskDate.addDays(AssignmentTaskDate.today(nowEpochMs), 1);
    return AssignmentDateRange.forDay(AssignmentTaskDate.toDayStartEpochMs(date));
  }

  static thisWeek(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    let today = AssignmentTaskDate.today(nowEpochMs);
    let weekday = AssignmentTaskDate.weekday(today);
    let mondayBased = weekday === 0 ? 7 : weekday;
    let endExclusive = AssignmentTaskDate.addDays(today, 8 - mondayBased);
    return {
      fromEpochMs: AssignmentTaskDate.toDayStartEpochMs(today),
      toEpochMs: AssignmentTaskDate.toDayStartEpochMs(endExclusive) - 1
    };
  }

  static startOfDay(epochMs: number): number {
    return AssignmentTaskDate.toDayStartEpochMs(AssignmentTaskDate.fromEpochMs(epochMs));
  }
}
