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
      return `超出 ${this.clock(-remaining)}`;
    }
    if (this.isPaused()) {
      if (remaining >= 0) return `已暂停 · 还剩 ${this.clock(remaining)}`;
      return `已暂停 · 超出 ${this.clock(-remaining)}`;
    }
    if (this.assignment.elapsedSeconds > 0) return `用了 ${this.clock(this.assignment.elapsedSeconds)}`;
    return `预计 ${this.assignment.expectedMinutes} 分钟`;
  }

  private progressValue(): number {
    return Math.min(this.elapsedSeconds(), this.budgetSeconds());
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('计时')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isOvertime() ? AppTheme.WARNING : AppTheme.PRIMARY);
        Text(this.headline())
          .layoutWeight(1)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isOvertime() ? AppTheme.WARNING : AppTheme.TEXT);
        Text(`目标 ${this.assignment.expectedMinutes} 分钟`)
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');

      Progress({ value: this.progressValue(), total: this.budgetSeconds(), type: ProgressType.Linear })
        .width('100%')
        .height(5)
        .color(this.isOvertime() ? AppTheme.WARNING : AppTheme.PRIMARY)
        .backgroundColor(this.isOvertime() ? AppTheme.WARNING_SOFT : AppTheme.PRIMARY_SOFT);
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.isOvertime() ? AppTheme.WARNING_SOFT : AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }
}
