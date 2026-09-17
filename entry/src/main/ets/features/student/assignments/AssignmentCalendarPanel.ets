import { AppTheme } from '../../../common/theme/AppTheme';
import { Assignment, AssignmentStatus, AssignmentType } from '../../../domain/model/HomeworkModels';

@Component
export struct AssignmentCalendarPanel {
  @Prop assignments: Assignment[] = [];
  @Link selectedDayEpochMs: number;
  @Link monthEpochMs: number;
  onSelectDay: (dayEpochMs: number) => void = (_dayEpochMs: number) => {};

  private monthStart(epochMs: number): number {
    let value = new Date(epochMs);
    return new Date(value.getFullYear(), value.getMonth(), 1).getTime();
  }

  private startOfDay(epochMs: number): number {
    let value = new Date(epochMs);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate()).getTime();
  }

  private addDays(dayStart: number, days: number): number {
    let value = new Date(dayStart);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate() + days).getTime();
  }

  private addMonths(monthStart: number, months: number): number {
    let value = new Date(monthStart);
    return new Date(value.getFullYear(), value.getMonth() + months, 1).getTime();
  }

  private monthLabel(): string {
    let value = new Date(this.monthStart(this.monthEpochMs));
    return `${value.getFullYear()}年${value.getMonth() + 1}月`;
  }

  private monthDays(): number[][] {
    let first = this.monthStart(this.monthEpochMs);
    let weekday = new Date(first).getDay();
    let mondayBasedOffset = weekday === 0 ? 6 : weekday - 1;
    let gridStart = this.addDays(first, -mondayBasedOffset);
    let weeks: number[][] = [];
    for (let row = 0; row < 6; row++) {
      let days: number[] = [];
      for (let column = 0; column < 7; column++) {
        days.push(this.addDays(gridStart, row * 7 + column));
      }
      weeks.push(days);
    }
    return weeks;
  }

  private isCurrentMonth(dayEpochMs: number): boolean {
    return this.monthStart(dayEpochMs) === this.monthStart(this.monthEpochMs);
  }

  private isSelected(dayEpochMs: number): boolean {
    return this.startOfDay(dayEpochMs) === this.startOfDay(this.selectedDayEpochMs);
  }

  private isToday(dayEpochMs: number): boolean {
    return this.startOfDay(dayEpochMs) === this.startOfDay(Date.now());
  }

  private dayAssignments(dayEpochMs: number): Assignment[] {
    let dayStart = this.startOfDay(dayEpochMs);
    let result: Assignment[] = [];
    for (let item of this.assignments) {
      if (item.dueAtEpochMs <= 0) continue;
      if (this.startOfDay(item.dueAtEpochMs) === dayStart) result.push(item);
    }
    return result;
  }

  private hasType(items: Assignment[], type: AssignmentType): boolean {
    for (let item of items) if (item.assignmentType === type) return true;
    return false;
  }

  private hasCompleted(items: Assignment[]): boolean {
    for (let item of items) if (item.status === AssignmentStatus.COMPLETED) return true;
    return false;
  }

  private selectDay(dayEpochMs: number): void {
    this.selectedDayEpochMs = this.startOfDay(dayEpochMs);
    if (!this.isCurrentMonth(dayEpochMs)) this.monthEpochMs = this.monthStart(dayEpochMs);
    this.onSelectDay(this.selectedDayEpochMs);
  }

  private previousMonth(): void {
    this.monthEpochMs = this.addMonths(this.monthStart(this.monthEpochMs), -1);
  }

  private nextMonth(): void {
    this.monthEpochMs = this.addMonths(this.monthStart(this.monthEpochMs), 1);
  }

  @Builder
  private DayMarkers(items: Assignment[]) {
    Row({ space: 2 }) {
      if (this.hasType(items, AssignmentType.SCHOOL)) {
        Text('课').fontSize(8).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
      }
      if (this.hasType(items, AssignmentType.EXTRA)) {
        Text('外').fontSize(8).fontWeight(FontWeight.Medium).fontColor(AppTheme.WARNING);
      }
      if (this.hasCompleted(items)) {
        Text('✓').fontSize(8).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS);
      }
    }
    .height(11)
    .justifyContent(FlexAlign.Center);
  }

  @Builder
  private DayCell(dayEpochMs: number) {
    Column({ space: 1 }) {
      Text(`${new Date(dayEpochMs).getDate()}`)
        .fontSize(13)
        .fontWeight(this.isToday(dayEpochMs) || this.isSelected(dayEpochMs) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.isSelected(dayEpochMs) ? AppTheme.TEXT_ON_PRIMARY :
          (this.isCurrentMonth(dayEpochMs) ? AppTheme.TEXT : AppTheme.TERTIARY_TEXT));
      this.DayMarkers(this.dayAssignments(dayEpochMs));
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.isSelected(dayEpochMs) ? AppTheme.PRIMARY :
      (this.isToday(dayEpochMs) ? AppTheme.PRIMARY_FAINT : Color.Transparent))
    .borderRadius(AppTheme.CHIP_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${new Date(dayEpochMs).getMonth() + 1}月${new Date(dayEpochMs).getDate()}日，${this.dayAssignments(dayEpochMs).length}项任务`)
    .onClick(() => this.selectDay(dayEpochMs));
  }

  @Builder
  private WeekdayHeader() {
    Row() {
      ForEach(['一', '二', '三', '四', '五', '六', '日'], (label: string) => {
        Text(label).layoutWeight(1).textAlign(TextAlign.Center).fontSize(11).fontColor(AppTheme.SUBTEXT);
      }, (label: string) => label);
    }
    .width('100%');
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text(this.monthLabel()).fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('课=课内 · 外=课外 · ✓=已完成').fontSize(10).fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Button('‹', { type: ButtonType.Normal })
          .width(AppTheme.MIN_TOUCH_TARGET).height(AppTheme.MIN_TOUCH_TARGET)
          .backgroundColor(AppTheme.SURFACE_SUBTLE).fontColor(AppTheme.TEXT)
          .borderRadius(AppTheme.CHIP_RADIUS).onClick(() => this.previousMonth());
        Button('›', { type: ButtonType.Normal })
          .width(AppTheme.MIN_TOUCH_TARGET).height(AppTheme.MIN_TOUCH_TARGET)
          .backgroundColor(AppTheme.SURFACE_SUBTLE).fontColor(AppTheme.TEXT)
          .borderRadius(AppTheme.CHIP_RADIUS).margin({ left: 6 }).onClick(() => this.nextMonth());
      }
      .width('100%');

      this.WeekdayHeader();
      Column({ space: 2 }) {
        ForEach(this.monthDays(), (week: number[]) => {
          Row({ space: 2 }) {
            ForEach(week, (dayEpochMs: number) => {
              this.DayCell(dayEpochMs);
            }, (dayEpochMs: number) => `${dayEpochMs}`);
          }
          .width('100%');
        }, (week: number[]) => `${week[0]}`);
      }
      .width('100%');
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }
}
