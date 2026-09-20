export interface AssignmentEpochRange {
  fromEpochMs: number;
  toEpochMs: number;
}

export class AssignmentDateRange {
  static forDay(dayEpochMs: number): AssignmentEpochRange {
    let dayStart = AssignmentDateRange.startOfDay(dayEpochMs);
    return {
      fromEpochMs: dayStart,
      toEpochMs: AssignmentDateRange.addDays(dayStart, 1) - 1
    };
  }

  static today(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    return AssignmentDateRange.forDay(nowEpochMs);
  }

  static tomorrow(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    let today = AssignmentDateRange.startOfDay(nowEpochMs);
    return AssignmentDateRange.forDay(AssignmentDateRange.addDays(today, 1));
  }

  static thisWeek(nowEpochMs: number = Date.now()): AssignmentEpochRange {
    let today = AssignmentDateRange.startOfDay(nowEpochMs);
    let weekday = new Date(today).getDay();
    let mondayBased = weekday === 0 ? 7 : weekday;
    return {
      fromEpochMs: today,
      toEpochMs: AssignmentDateRange.addDays(today, 8 - mondayBased) - 1
    };
  }

  static startOfDay(epochMs: number): number {
    let value = new Date(epochMs);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate()).getTime();
  }

  private static addDays(dayStart: number, days: number): number {
    let value = new Date(dayStart);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate() + days).getTime();
  }
}
