import { Assignment, AssignmentStatus } from '../model/HomeworkModels';

export enum DueDateFilterKey {
  ALL = 'ALL',
  TODAY = 'TODAY',
  TOMORROW = 'TOMORROW',
  THIS_WEEK = 'THIS_WEEK',
  OVERDUE = 'OVERDUE'
}

export class AssignmentDueDate {
  static matches(item: Assignment, filter: DueDateFilterKey, nowEpochMs: number = Date.now()): boolean {
    if (filter === DueDateFilterKey.ALL) return true;
    if (filter === DueDateFilterKey.OVERDUE) return AssignmentDueDate.isOverdue(item, nowEpochMs);

    let dueDay = AssignmentDueDate.assignmentDayStart(item, nowEpochMs);
    if (dueDay < 0) return false;

    let today = AssignmentDueDate.startOfDay(nowEpochMs);
    if (filter === DueDateFilterKey.TODAY) return dueDay === today;
    if (filter === DueDateFilterKey.TOMORROW) return dueDay === AssignmentDueDate.addDays(today, 1);
    if (filter === DueDateFilterKey.THIS_WEEK) {
      return dueDay >= today && dueDay <= AssignmentDueDate.endOfWeek(today);
    }
    return false;
  }

  static resolveDateKey(dueText: string, nowEpochMs: number = Date.now()): string {
    let dayStart = AssignmentDueDate.resolveDayStart(dueText, nowEpochMs);
    return dayStart < 0 ? '' : AssignmentDueDate.formatDateKey(dayStart);
  }

  static resolveDayStart(dueText: string, nowEpochMs: number = Date.now()): number {
    let text = dueText.trim();
    if (text.length === 0) return -1;

    let today = AssignmentDueDate.startOfDay(nowEpochMs);
    if (text.indexOf('今天') >= 0 || text.indexOf('今日') >= 0 || text.indexOf('今晚') >= 0 || text.indexOf('晚上') >= 0) {
      return today;
    }
    if (text.indexOf('明天') >= 0 || text.indexOf('明日') >= 0) return AssignmentDueDate.addDays(today, 1);
    if (text.indexOf('后天') >= 0) return AssignmentDueDate.addDays(today, 2);

    let weekday = AssignmentDueDate.weekdayNumber(text);
    if (weekday > 0) {
      let current = new Date(today).getDay();
      let currentMondayBased = current === 0 ? 7 : current;
      let delta = (weekday - currentMondayBased + 7) % 7;
      return AssignmentDueDate.addDays(today, delta);
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
      let now = new Date(nowEpochMs);
      return AssignmentDueDate.dateStart(now.getFullYear(), Number(monthDay[1]), Number(monthDay[2]));
    }

    let numericMonthDay = text.match(/(^|[^\d])(\d{1,2})[-\/.](\d{1,2})($|[^\d])/);
    if (numericMonthDay !== null && numericMonthDay.length >= 4) {
      let now = new Date(nowEpochMs);
      return AssignmentDueDate.dateStart(now.getFullYear(), Number(numericMonthDay[2]), Number(numericMonthDay[3]));
    }
    return -1;
  }

  private static assignmentDayStart(item: Assignment, nowEpochMs: number): number {
    let key = item.dueDateKey;
    if (key !== undefined && key.length > 0) {
      let frozen = AssignmentDueDate.dayStartFromKey(key);
      if (frozen >= 0) return frozen;
    }
    let anchor = AssignmentDueDate.assignmentCreatedAt(item.id);
    return AssignmentDueDate.resolveDayStart(item.dueText, anchor > 0 ? anchor : nowEpochMs);
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
    let dueDay = AssignmentDueDate.assignmentDayStart(item, nowEpochMs);
    return dueDay >= 0 && dueDay < AssignmentDueDate.startOfDay(nowEpochMs);
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

  private static startOfDay(epochMs: number): number {
    let value = new Date(epochMs);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate()).getTime();
  }

  private static addDays(dayStart: number, days: number): number {
    let value = new Date(dayStart);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate() + days).getTime();
  }

  private static endOfWeek(todayStart: number): number {
    let weekday = new Date(todayStart).getDay();
    let mondayBased = weekday === 0 ? 7 : weekday;
    return AssignmentDueDate.addDays(todayStart, 7 - mondayBased);
  }

  private static dayStartFromKey(key: string): number {
    let match = key.match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (match === null || match.length < 4) return -1;
    return AssignmentDueDate.dateStart(Number(match[1]), Number(match[2]), Number(match[3]));
  }

  private static formatDateKey(dayStart: number): string {
    let value = new Date(dayStart);
    let month = value.getMonth() + 1;
    let day = value.getDate();
    let monthText = month < 10 ? `0${month}` : `${month}`;
    let dayText = day < 10 ? `0${day}` : `${day}`;
    return `${value.getFullYear()}-${monthText}-${dayText}`;
  }

  private static dateStart(year: number, month: number, day: number): number {
    if (month < 1 || month > 12 || day < 1 || day > 31) return -1;
    let value = new Date(year, month - 1, day);
    if (value.getFullYear() !== year || value.getMonth() !== month - 1 || value.getDate() !== day) return -1;
    return value.getTime();
  }
}
