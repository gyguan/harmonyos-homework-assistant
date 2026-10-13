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

    let weekdayDate = AssignmentTaskDate.resolveWeekday(text, today);
    if (weekdayDate.length > 0) return weekdayDate;

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

  private static resolveWeekday(text: string, today: string): string {
    let match = text.match(/(下周|下星期|本周|本星期|这周|这星期|周|星期)([一二三四五六日天])/);
    if (match === null || match.length < 3) return '';
    let target = AssignmentTaskDate.weekdayNumber(match[2]);
    if (target < 0) return '';

    let current = AssignmentTaskDate.weekday(today);
    if (current < 0) return '';
    let prefix = match[1];
    if (prefix === '下周' || prefix === '下星期') {
      let currentMondayBased = current === 0 ? 7 : current;
      let targetMondayBased = target === 0 ? 7 : target;
      return AssignmentTaskDate.addDays(today, (8 - currentMondayBased) + targetMondayBased - 1);
    }
    let delta = (target - current + 7) % 7;
    return AssignmentTaskDate.addDays(today, delta);
  }

  private static weekdayNumber(value: string): number {
    if (value === '一') return 1;
    if (value === '二') return 2;
    if (value === '三') return 3;
    if (value === '四') return 4;
    if (value === '五') return 5;
    if (value === '六') return 6;
    if (value === '日' || value === '天') return 0;
    return -1;
  }

  static weekday(taskDate: string): number {
    let parts = AssignmentTaskDate.parse(taskDate);
    if (parts === null) return -1;
    return new Date(Date.UTC(parts.year, parts.month - 1, parts.day)).getUTCDay();
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
