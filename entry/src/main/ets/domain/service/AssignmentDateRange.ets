import { AssignmentDueDate } from './AssignmentDueDate';

export interface AssignmentEpochRange {
  fromEpochMs: number;
  toEpochMs: number;
}

export class AssignmentDateRange {
  static forDay(dayEpochMs: number): AssignmentEpochRange {
    let dayStart = AssignmentDueDate.businessDayStart(dayEpochMs);
    return {
      fromEpochMs: dayStart,
      toEpochMs: AssignmentDueDate.addBusinessDays(dayStart, 1) - 1
    };
  }

  static today(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    return AssignmentDateRange.forDay(nowEpochMs);
  }

  static tomorrow(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    let today = AssignmentDueDate.businessDayStart(nowEpochMs);
    return AssignmentDateRange.forDay(AssignmentDueDate.addBusinessDays(today, 1));
  }

  static thisWeek(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    let today = AssignmentDueDate.businessDayStart(nowEpochMs);
    let weekday = AssignmentDueDate.businessWeekday(today);
    let mondayBased = weekday === 0 ? 7 : weekday;
    return {
      fromEpochMs: today,
      toEpochMs: AssignmentDueDate.addBusinessDays(today, 8 - mondayBased) - 1
    };
  }

  static startOfDay(epochMs: number): number {
    return AssignmentDueDate.businessDayStart(epochMs);
  }
}
