export interface AssignmentDateParts {
  year: number;
  month: number;
  day: number;
}

export class AssignmentTaskDate {
  private static readonly SHANGHAI_OFFSET_HOURS: number = 8;

  static today(nowEpochMs: number = Date.now()): string {
    return AssignmentTaskDate.fromEpochMs(nowEpochMs);
  }

  static tomorrow(nowEpochMs: number = Date.now()): string {
    return AssignmentTaskDate.addDays(AssignmentTaskDate.today(nowEpochMs), 1);
  }

  static fromEpochMs(epochMs: number): string {
    let shifted = new Date(epochMs + AssignmentTaskDate.SHANGHAI_OFFSET_HOURS * 60 * 60 * 1000);
    return AssignmentTaskDate.format(
      shifted.getUTCFullYear(), shifted.getUTCMonth() + 1, shifted.getUTCDate());
  }

  static toDayStartEpochMs(taskDate: string): number {
    let parts = AssignmentTaskDate.parse(taskDate);
    if (parts === null) return -1;
    return Date.UTC(parts.year, parts.month - 1, parts.day,
      -AssignmentTaskDate.SHANGHAI_OFFSET_HOURS, 0, 0, 0);
  }

  static isValid(taskDate: string): boolean {
    return AssignmentTaskDate.parse(taskDate) !== null;
  }

  static addDays(taskDate: string, days: number): string {
    let parts = AssignmentTaskDate.parse(taskDate);
    if (parts === null) return '';
    let shifted = new Date(Date.UTC(parts.year, parts.month - 1, parts.day + days));
    return AssignmentTaskDate.format(
      shifted.getUTCFullYear(), shifted.getUTCMonth() + 1, shifted.getUTCDate());
  }

  static displayText(taskDate: string, nowEpochMs: number = Date.now()): string {
    if (!AssignmentTaskDate.isValid(taskDate)) return taskDate;
    let today = AssignmentTaskDate.today(nowEpochMs);
    if (taskDate === today) return '今天';
    if (taskDate === AssignmentTaskDate.addDays(today, 1)) return '明天';
    let parts = AssignmentTaskDate.parse(taskDate)!;
    return `${parts.month}月${parts.day}日`;
  }

  static parse(taskDate: string): AssignmentDateParts | null {
    let match = taskDate.trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (match === null || match.length < 4) return null;
    let year = Number(match[1]);
    let month = Number(match[2]);
    let day = Number(match[3]);
    let value = new Date(Date.UTC(year, month - 1, day));
    if (value.getUTCFullYear() !== year || value.getUTCMonth() !== month - 1 ||
      value.getUTCDate() !== day) return null;
    return { year: year, month: month, day: day };
  }

  private static format(year: number, month: number, day: number): string {
    return `${year}-${AssignmentTaskDate.pad(month)}-${AssignmentTaskDate.pad(day)}`;
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
