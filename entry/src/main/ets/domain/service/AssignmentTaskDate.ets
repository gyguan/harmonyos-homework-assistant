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

  static resolve(value: string, nowEpochMs: number = Date.now()): string {
    let text = value.trim();
    if (text.length === 0) return AssignmentTaskDate.today(nowEpochMs);
    let parsed = AssignmentTaskDate.parse(text);
    if (parsed !== null) return AssignmentTaskDate.format(parsed.year, parsed.month, parsed.day);
    let today = AssignmentTaskDate.today(nowEpochMs);
    if (text.indexOf('后天') >= 0) return AssignmentTaskDate.addDays(today, 2);
    if (text.indexOf('明天') >= 0 || text.indexOf('明日') >= 0) return AssignmentTaskDate.addDays(today, 1);
    if (text.indexOf('今天') >= 0 || text.indexOf('今日') >= 0 || text.indexOf('今晚') >= 0) return today;

    let full = text.match(/(\d{4})年(\d{1,2})月(\d{1,2})[日号]?/);
    if (full !== null && full.length >= 4) {
      let result = AssignmentTaskDate.format(Number(full[1]), Number(full[2]), Number(full[3]));
      return AssignmentTaskDate.isValid(result) ? result : today;
    }
    let monthDay = text.match(/(\d{1,2})月(\d{1,2})[日号]?/);
    if (monthDay !== null && monthDay.length >= 3) {
      let now = AssignmentTaskDate.parse(today)!;
      let result = AssignmentTaskDate.format(now.year, Number(monthDay[1]), Number(monthDay[2]));
      return AssignmentTaskDate.isValid(result) ? result : today;
    }
    return today;
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
