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
    if (filter === DueDateFilterKey.OVERDUE) return this.isOverdue(item, nowEpochMs);

    let dueDay = this.resolveDayStart(item.dueText, nowEpochMs);
    if (dueDay < 0) return false;

    let today = this.startOfDay(nowEpochMs);
    if (filter === DueDateFilterKey.TODAY) return dueDay === today;
    if (filter === DueDateFilterKey.TOMORROW) return dueDay === this.addDays(today, 1);
    if (filter === DueDateFilterKey.THIS_WEEK) {
      return dueDay >= today && dueDay <= this.endOfWeek(today);
    }
    return false;
  }

  static resolveDayStart(dueText: string, nowEpochMs: number = Date.now()): number {
    let text = dueText.trim();
    if (text.length === 0) return -1;

    let today = this.startOfDay(nowEpochMs);
    if (text.indexOf('今天') >= 0 || text.indexOf('今日') >= 0 || text.indexOf('今晚') >= 0 || text.indexOf('晚上') >= 0) {
      return today;
    }
    if (text.indexOf('明天') >= 0 || text.indexOf('明日') >= 0) return this.addDays(today, 1);
    if (text.indexOf('后天') >= 0) return this.addDays(today, 2);

    let weekday = this.weekdayNumber(text);
    if (weekday > 0) {
      let current = new Date(today).getDay();
      let currentMondayBased = current === 0 ? 7 : current;
      let delta = (weekday - currentMondayBased + 7) % 7;
      return this.addDays(today, delta);
    }

    let chineseFull = text.match(/(\d{4})年(\d{1,2})月(\d{1,2})[日号]?/);
    if (chineseFull !== null && chineseFull.length >= 4) {
      return this.dateStart(Number(chineseFull[1]), Number(chineseFull[2]), Number(chineseFull[3]));
    }

    let numericFull = text.match(/(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})/);
    if (numericFull !== null && numericFull.length >= 4) {
      return this.dateStart(Number(numericFull[1]), Number(numericFull[2]), Number(numericFull[3]));
    }

    let monthDay = text.match(/(\d{1,2})月(\d{1,2})[日号]?/);
    if (monthDay !== null && monthDay.length >= 3) {
      let now = new Date(nowEpochMs);
      return this.dateStart(now.getFullYear(), Number(monthDay[1]), Number(monthDay[2]));
    }

    let numericMonthDay = text.match(/(^|[^\d])(\d{1,2})[-\/.](\d{1,2})($|[^\d])/);
    if (numericMonthDay !== null && numericMonthDay.length >= 4) {
      let now = new Date(nowEpochMs);
      return this.dateStart(now.getFullYear(), Number(numericMonthDay[2]), Number(numericMonthDay[3]));
    }
    return -1;
  }

  private static isOverdue(item: Assignment, nowEpochMs: number): boolean {
    if (item.status === AssignmentStatus.COMPLETED || item.status === AssignmentStatus.SUBMITTED) return false;
    if (item.status === AssignmentStatus.OVERDUE) return true;
    let dueDay = this.resolveDayStart(item.dueText, nowEpochMs);
    return dueDay >= 0 && dueDay < this.startOfDay(nowEpochMs);
  }

  private static weekdayNumber(text: string): number {
    let labels: string[] = ['周一', '星期一', '周二', '星期二', '周三', '星期三', '周四', '星期四',
      '周五', '星期五', '周六', '星期六', '周日', '星期日', '周天', '星期天'];
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
    return this.addDays(todayStart, 7 - mondayBased);
  }

  private static dateStart(year: number, month: number, day: number): number {
    if (month < 1 || month > 12 || day < 1 || day > 31) return -1;
    let value = new Date(year, month - 1, day);
    if (value.getFullYear() !== year || value.getMonth() !== month - 1 || value.getDate() !== day) return -1;
    return value.getTime();
  }
}
