import { AppTheme } from '../../common/theme/AppTheme';
import { Assignment, AssignmentStatus } from '../../domain/model/HomeworkModels';

@Component
export struct AssignmentCountdownCard {
  @Prop assignment: Assignment;
  @State private nowEpochMs: number = Date.now();
  private timerId: number = -1;

  aboutToAppear(): void {
    this.nowEpochMs = Date.now();
    if (this.timerId < 0) {
      this.timerId = setInterval(() => {
        this.nowEpochMs = Date.now();
      }, 1000);
    }
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private budgetSeconds(): number {
    return Math.max(1, this.assignment.expectedMinutes) * 60;
  }

  private elapsedSeconds(): number {
    let accumulated = Math.max(0, this.assignment.elapsedSeconds);
    if (this.assignment.status !== AssignmentStatus.IN_PROGRESS || this.assignment.startedAtEpochMs <= 0) {
      return accumulated;
    }
    return accumulated + Math.max(0, Math.floor((this.nowEpochMs - this.assignment.startedAtEpochMs) / 1000));
  }

  private clock(seconds: number): string {
    let safe = Math.max(0, Math.floor(seconds));
    let minutes = Math.floor(safe / 60);
    let remain = safe % 60;
    return `${minutes}:${remain < 10 ? '0' : ''}${remain}`;
  }

  private isRunning(): boolean {
    return this.assignment.status === AssignmentStatus.IN_PROGRESS && this.assignment.startedAtEpochMs > 0;
  }

  private isPaused(): boolean {
    return this.assignment.status === AssignmentStatus.PAUSED;
  }

  private isOvertime(): boolean {
    return this.isRunning() && this.elapsedSeconds() > this.budgetSeconds();
  }

  private headline(): string {
    let remaining = this.budgetSeconds() - this.elapsedSeconds();
    if (this.isRunning()) {
      if (remaining >= 0) return `还剩 ${this.clock(remaining)}`;
      return `已超出 ${this.clock(-remaining)}`;
    }
    if (this.isPaused()) {
      if (remaining >= 0) return `已暂停 · 还剩 ${this.clock(remaining)}`;
      return `已暂停 · 已超出 ${this.clock(-remaining)}`;
    }
    if (this.assignment.elapsedSeconds > 0) {
      return `实际用时 ${this.clock(this.assignment.elapsedSeconds)}`;
    }
    return `预计 ${this.assignment.expectedMinutes} 分钟`;
  }

  private hint(): string {
    if (this.isRunning()) {
      return this.isOvertime() ? '不用着急，先把这项作业认真完成。' : '专心完成这一项，小伴帮你看着时间。';
    }
    if (this.isPaused()) {
      return `已经专注 ${this.clock(this.assignment.elapsedSeconds)}，继续后从这里接着计时。`;
    }
    if (this.assignment.elapsedSeconds > 0) {
      let actualMinutes = Math.max(1, Math.round(this.assignment.elapsedSeconds / 60));
      if (actualMinutes <= this.assignment.expectedMinutes) return `比预计时间快 ${this.assignment.expectedMinutes - actualMinutes} 分钟。`;
      return `比预计时间多用了 ${actualMinutes - this.assignment.expectedMinutes} 分钟。`;
    }
    return '点击“开始作业”后开始倒计时。';
  }

  private progressValue(): number {
    return Math.min(this.elapsedSeconds(), this.budgetSeconds());
  }

  build() {
    Column({ space: 9 }) {
      if (this.assignment.status === AssignmentStatus.NEEDS_REWORK && this.assignment.reviewNote.length > 0) {
        Column({ space: 4 }) {
          Text('家长请你订正').width('100%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.DANGER);
          Text(this.assignment.reviewNote).width('100%').fontSize(14).lineHeight(20).fontColor(AppTheme.TEXT);
        }.width('100%').padding(11).backgroundColor(AppTheme.DANGER_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
      }

      Row() {
        Text('作业计时')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT);
        Blank();
        Text(`目标 ${this.assignment.expectedMinutes} 分钟`)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');

      Text(this.headline())
        .width('100%')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isOvertime() ? AppTheme.WARNING : AppTheme.TEXT);

      Progress({ value: this.progressValue(), total: this.budgetSeconds(), type: ProgressType.Linear })
        .width('100%')
        .height(7)
        .color(this.isOvertime() ? AppTheme.WARNING : AppTheme.PRIMARY)
        .backgroundColor(this.isOvertime() ? AppTheme.WARNING_SOFT : AppTheme.PRIMARY_SOFT);

      Text(this.hint())
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(this.isOvertime() ? AppTheme.WARNING : AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isOvertime() ? AppTheme.WARNING_SOFT : AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }
}
