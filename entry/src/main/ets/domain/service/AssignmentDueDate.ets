import { Assignment, AssignmentStatus } from '../model/HomeworkModels';

interface DueDateParts {
  year: number;
  month: number;
  day: number;
}

export enum DueDateFilterKey {
  ALL = 'ALL',
  TODAY = 'TODAY',
  TOMORROW = 'TOMORROW',
  THIS_WEEK = 'THIS_WEEK',
  OVERDUE = 'OVERDUE'
}

export class AssignmentDueDate {
  private static readonly SHANGHAI_OFFSET_HOURS: number = 8;
  private static readonly DEFAULT_DUE_HOUR: number = 23;
  private static readonly DEFAULT_DUE_MINUTE: number = 59;

  static resolveDueAtEpochMs(dueText: string, anchorEpochMs: number = Date.now()): number {
    let text = dueText.trim();
    if (text.length === 0) return -1;

    let date = AssignmentDueDate.resolveShanghaiDate(text, anchorEpochMs);
    let timeMinutes = AssignmentDueDate.resolveTimeMinutes(text);
    if (date === null) {
      if (timeMinutes < 0) return -1;
      date = AssignmentDueDate.shanghaiDateParts(anchorEpochMs);
    }

    let hour = AssignmentDueDate.DEFAULT_DUE_HOUR;
    let minute = AssignmentDueDate.DEFAULT_DUE_MINUTE;
    if (timeMinutes >= 0) {
      hour = Math.floor(timeMinutes / 60);
      minute = timeMinutes % 60;
    }

    return Date.UTC(date.year, date.month - 1, date.day,
      hour - AssignmentDueDate.SHANGHAI_OFFSET_HOURS, minute, 0, 0);
  }

  static displayText(item: Assignment): string {
    let dueAt = item.dueAtEpochMs;
    if (dueAt <= 0) {
      let anchor = AssignmentDueDate.assignmentCreatedAt(item.id);
      dueAt = AssignmentDueDate.resolveDueAtEpochMs(
        item.dueText, anchor > 0 ? anchor : Date.now());
    }
    if (dueAt <= 0) return '未设置截止时间';

    let shifted = new Date(dueAt + AssignmentDueDate.SHANGHAI_OFFSET_HOURS * 60 * 60 * 1000);
    let year = shifted.getUTCFullYear();
    let month = AssignmentDueDate.pad(shifted.getUTCMonth() + 1);
    let day = AssignmentDueDate.pad(shifted.getUTCDate());
    let hour = AssignmentDueDate.pad(shifted.getUTCHours());
    let minute = AssignmentDueDate.pad(shifted.getUTCMinutes());
    return `${year}-${month}-${day} ${hour}:${minute}`;
  }

  static matches(item: Assignment, filter: DueDateFilterKey, nowEpochMs: number = Date.now()): boolean {
    if (filter === DueDateFilterKey.ALL) return true;
    if (filter === DueDateFilterKey.OVERDUE) return AssignmentDueDate.isOverdue(item, nowEpochMs);

    let dueDay = AssignmentDueDate.dayStart(item, nowEpochMs);
    if (dueDay < 0) return false;

    let today = AssignmentDueDate.businessDayStart(nowEpochMs);
    if (filter === DueDateFilterKey.TODAY) return dueDay === today;
    if (filter === DueDateFilterKey.TOMORROW) return dueDay === AssignmentDueDate.addBusinessDays(today, 1);
    if (filter === DueDateFilterKey.THIS_WEEK) {
      return dueDay >= today && dueDay <= AssignmentDueDate.endOfWeek(today);
    }
    return false;
  }

  static dayStart(item: Assignment, nowEpochMs: number = Date.now()): number {
    if (item.dueAtEpochMs > 0) return AssignmentDueDate.businessDayStart(item.dueAtEpochMs);

    let key = item.dueDateKey;
    if (key !== undefined && key.length > 0) {
      let frozen = AssignmentDueDate.dayStartFromKey(key);
      if (frozen >= 0) return frozen;
    }

    let anchor = AssignmentDueDate.assignmentCreatedAt(item.id);
    return AssignmentDueDate.resolveDayStart(item.dueText, anchor > 0 ? anchor : nowEpochMs);
  }

  static resolveDateKey(dueText: string, nowEpochMs: number = Date.now()): string {
    let dayStart = AssignmentDueDate.resolveDayStart(dueText, nowEpochMs);
    return dayStart < 0 ? '' : AssignmentDueDate.formatDateKey(dayStart);
  }

  static resolveDayStart(dueText: string, nowEpochMs: number = Date.now()): number {
    let text = dueText.trim();
    if (text.length === 0) return -1;

    let today = AssignmentDueDate.businessDayStart(nowEpochMs);
    if (text.indexOf('今天') >= 0 || text.indexOf('今日') >= 0 || text.indexOf('今晚') >= 0 || text.indexOf('晚上') >= 0) {
      return today;
    }
    if (text.indexOf('明天') >= 0 || text.indexOf('明日') >= 0) return AssignmentDueDate.addBusinessDays(today, 1);
    if (text.indexOf('后天') >= 0) return AssignmentDueDate.addBusinessDays(today, 2);

    let weekday = AssignmentDueDate.weekdayNumber(text);
    if (weekday > 0) {
      let current = AssignmentDueDate.businessWeekday(today);
      let currentMondayBased = current === 0 ? 7 : current;
      let delta = (weekday - currentMondayBased + 7) % 7;
      return AssignmentDueDate.addBusinessDays(today, delta);
    }

    let chineseFull = text.match(/(\d{4})年(\d{1,2})月(\d{1,2})[日号]?/);
    if (chineseFull !== null && chineseFull.length >= 4) {
      return AssignmentDueDate.dateStart(Number(chineseFull[1]), Number(chineseFull[2]), Number(chineseFull[3]));
    }

    let numericFull = text.match(/(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})/);
    if (numericFull !== null && numericFull.length >= 4) {
      return AssignmentDueDate.dateStart(Number(numericFull[1]), Number(numericFull[2]), Number(numericFull[3]));
    }

    let monthDay = text.match(/(\d{1,2})月(\d{1,2})[日号]?/);
    if (monthDay !== null && monthDay.length >= 3) {
      let now = AssignmentDueDate.shanghaiDateParts(nowEpochMs);
      return AssignmentDueDate.dateStart(now.year, Number(monthDay[1]), Number(monthDay[2]));
    }

    let numericMonthDay = text.match(/(^|[^\d])(\d{1,2})[-\/.](\d{1,2})($|[^\d])/);
    if (numericMonthDay !== null && numericMonthDay.length >= 4) {
      let now = AssignmentDueDate.shanghaiDateParts(nowEpochMs);
      return AssignmentDueDate.dateStart(now.year, Number(numericMonthDay[2]), Number(numericMonthDay[3]));
    }
    return -1;
  }

  private static resolveShanghaiDate(text: string, anchorEpochMs: number): DueDateParts | null {
    let anchor = AssignmentDueDate.shanghaiDateParts(anchorEpochMs);

    let chineseFull = text.match(/(\d{4})年(\d{1,2})月(\d{1,2})[日号]?/);
    if (chineseFull !== null && chineseFull.length >= 4) {
      return AssignmentDueDate.validDateParts(
        Number(chineseFull[1]), Number(chineseFull[2]), Number(chineseFull[3]));
    }

    let numericFull = text.match(/(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})/);
    if (numericFull !== null && numericFull.length >= 4) {
      return AssignmentDueDate.validDateParts(
        Number(numericFull[1]), Number(numericFull[2]), Number(numericFull[3]));
    }

    let monthDay = text.match(/(\d{1,2})月(\d{1,2})[日号]?/);
    if (monthDay !== null && monthDay.length >= 3) {
      return AssignmentDueDate.validDateParts(
        anchor.year, Number(monthDay[1]), Number(monthDay[2]));
    }

    let numericMonthDay = text.match(/(^|[^\d])(\d{1,2})[-\/.](\d{1,2})($|[^\d])/);
    if (numericMonthDay !== null && numericMonthDay.length >= 4) {
      return AssignmentDueDate.validDateParts(
        anchor.year, Number(numericMonthDay[2]), Number(numericMonthDay[3]));
    }

    if (text.indexOf('今天') >= 0 || text.indexOf('今日') >= 0 || text.indexOf('今晚') >= 0) {
      return anchor;
    }
    if (text.indexOf('明天') >= 0 || text.indexOf('明日') >= 0) {
      return AssignmentDueDate.addCalendarDays(anchor, 1);
    }
    if (text.indexOf('后天') >= 0) {
      return AssignmentDueDate.addCalendarDays(anchor, 2);
    }

    let weekday = AssignmentDueDate.weekdayNumber(text);
    if (weekday > 0) {
      let current = new Date(Date.UTC(anchor.year, anchor.month - 1, anchor.day)).getUTCDay();
      let currentMondayBased = current === 0 ? 7 : current;
      let delta = (weekday - currentMondayBased + 7) % 7;
      return AssignmentDueDate.addCalendarDays(anchor, delta);
    }

    if (text.indexOf('晚上') >= 0) return anchor;
    return null;
  }

  private static resolveTimeMinutes(text: string): number {
    let colon = text.match(/(^|[^\d])(\d{1,2})[:：]([0-5]\d)($|[^\d])/);
    if (colon !== null && colon.length >= 4) {
      let hour = AssignmentDueDate.normalizeChineseHour(text, Number(colon[2]));
      let minute = Number(colon[3]);
      if (hour >= 0) return hour * 60 + minute;
    }

    let half = text.match(/(\d{1,2})点半/);
    if (half !== null && half.length >= 2) {
      let hour = AssignmentDueDate.normalizeChineseHour(text, Number(half[1]));
      if (hour >= 0) return hour * 60 + 30;
    }

    let chinese = text.match(/(\d{1,2})点(?:([0-5]?\d)分?)?/);
    if (chinese !== null && chinese.length >= 2) {
      let hour = AssignmentDueDate.normalizeChineseHour(text, Number(chinese[1]));
      let minute = chinese.length >= 3 && chinese[2] !== undefined && chinese[2].length > 0 ?
        Number(chinese[2]) : 0;
      if (hour >= 0 && minute >= 0 && minute <= 59) return hour * 60 + minute;
    }
    return -1;
  }

  private static normalizeChineseHour(text: string, hour: number): number {
    if (hour < 0 || hour > 23) return -1;
    if ((text.indexOf('下午') >= 0 || text.indexOf('晚上') >= 0 || text.indexOf('今晚') >= 0 ||
      text.indexOf('中午') >= 0) && hour < 12) {
      hour += 12;
    }
    return hour <= 23 ? hour : -1;
  }

  private static shanghaiDateParts(epochMs: number): DueDateParts {
    let shifted = new Date(epochMs + AssignmentDueDate.SHANGHAI_OFFSET_HOURS * 60 * 60 * 1000);
    return {
      year: shifted.getUTCFullYear(),
      month: shifted.getUTCMonth() + 1,
      day: shifted.getUTCDate()
    };
  }

  private static addCalendarDays(value: DueDateParts, days: number): DueDateParts {
    let shifted = new Date(Date.UTC(value.year, value.month - 1, value.day + days));
    return {
      year: shifted.getUTCFullYear(),
      month: shifted.getUTCMonth() + 1,
      day: shifted.getUTCDate()
    };
  }

  private static validDateParts(year: number, month: number, day: number): DueDateParts | null {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    let value = new Date(Date.UTC(year, month - 1, day));
    if (value.getUTCFullYear() !== year || value.getUTCMonth() !== month - 1 || value.getUTCDate() !== day) {
      return null;
    }
    return { year: year, month: month, day: day };
  }

  private static assignmentCreatedAt(assignmentId: string): number {
    let match = assignmentId.match(/(?:text|image)-(\d{13})/);
    if (match === null || match.length < 2) return -1;
    let value = Number(match[1]);
    return Number.isFinite(value) && value > 0 ? value : -1;
  }

  private static isOverdue(item: Assignment, nowEpochMs: number): boolean {
    if (item.status === AssignmentStatus.COMPLETED || item.status === AssignmentStatus.SUBMITTED) return false;
    if (item.status === AssignmentStatus.OVERDUE) return true;
    let dueDay = AssignmentDueDate.dayStart(item, nowEpochMs);
    return dueDay >= 0 && dueDay < AssignmentDueDate.businessDayStart(nowEpochMs);
  }

  private static weekdayNumber(text: string): number {
    if (text.indexOf('周日') >= 0 || text.indexOf('星期日') >= 0 || text.indexOf('周天') >= 0 || text.indexOf('星期天') >= 0) return 7;
    let labels: string[] = ['周一', '星期一', '周二', '星期二', '周三', '星期三', '周四', '星期四',
      '周五', '星期五', '周六', '星期六'];
    for (let i = 0; i < labels.length; i++) {
      if (text.indexOf(labels[i]) >= 0) return Math.floor(i / 2) + 1;
    }
    return -1;
  }

  static businessDayStart(epochMs: number): number {
    let value = AssignmentDueDate.shanghaiDateParts(epochMs);
    return Date.UTC(value.year, value.month - 1, value.day,
      -AssignmentDueDate.SHANGHAI_OFFSET_HOURS, 0, 0, 0);
  }

  static addBusinessDays(dayStart: number, days: number): number {
    let value = AssignmentDueDate.shanghaiDateParts(dayStart);
    let shifted = AssignmentDueDate.addCalendarDays(value, days);
    return Date.UTC(shifted.year, shifted.month - 1, shifted.day,
      -AssignmentDueDate.SHANGHAI_OFFSET_HOURS, 0, 0, 0);
  }

  static businessWeekday(epochMs: number): number {
    let value = AssignmentDueDate.shanghaiDateParts(epochMs);
    return new Date(Date.UTC(value.year, value.month - 1, value.day)).getUTCDay();
  }

  private static endOfWeek(todayStart: number): number {
    let weekday = AssignmentDueDate.businessWeekday(todayStart);
    let mondayBased = weekday === 0 ? 7 : weekday;
    return AssignmentDueDate.addBusinessDays(todayStart, 7 - mondayBased);
  }

  private static dayStartFromKey(key: string): number {
    let match = key.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (match === null || match.length < 4) return -1;
    return AssignmentDueDate.dateStart(Number(match[1]), Number(match[2]), Number(match[3]));
  }

  private static formatDateKey(dayStart: number): string {
    let value = AssignmentDueDate.shanghaiDateParts(dayStart);
    let monthText = value.month < 10 ? `0${value.month}` : `${value.month}`;
    let dayText = value.day < 10 ? `0${value.day}` : `${value.day}`;
    return `${value.year}-${monthText}-${dayText}`;
  }

  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static dateStart(year: number, month: number, day: number): number {
    let value = AssignmentDueDate.validDateParts(year, month, day);
    if (value === null) return -1;
    return Date.UTC(value.year, value.month - 1, value.day,
      -AssignmentDueDate.SHANGHAI_OFFSET_HOURS, 0, 0, 0);
  }
}
