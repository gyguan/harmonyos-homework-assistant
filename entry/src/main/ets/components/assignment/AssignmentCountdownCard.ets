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

  private remainingSeconds(): number {
    return this.budgetSeconds() - this.elapsedSeconds();
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
    return this.isRunning() && this.remainingSeconds() < 0;
  }

  private isNearDeadline(): boolean {
    let remaining = this.remainingSeconds();
    return this.isRunning() && remaining > 0 && remaining <= 5 * 60;
  }

  private statusLabel(): string {
    let remaining = this.remainingSeconds();
    if (this.isRunning()) return remaining >= 0 ? '还剩' : '超出';
    if (this.isPaused()) return remaining >= 0 ? '已暂停 · 还剩' : '已暂停 · 超出';
    if (this.assignment.elapsedSeconds > 0) return '用了';
    return '预计';
  }

  private timeValue(): string {
    let remaining = this.remainingSeconds();
    if (this.isRunning() || this.isPaused()) return this.clock(Math.abs(remaining));
    if (this.assignment.elapsedSeconds > 0) return this.clock(this.assignment.elapsedSeconds);
    return `${this.assignment.expectedMinutes} 分钟`;
  }

  private emphasisColor(): string {
    if (this.isOvertime()) return AppTheme.DANGER;
    if (this.isNearDeadline()) return AppTheme.WARNING;
    return AppTheme.PRIMARY;
  }

  private emphasisBackground(): string {
    if (this.isOvertime()) return AppTheme.DANGER_SOFT;
    if (this.isNearDeadline()) return AppTheme.WARNING_SOFT;
    return AppTheme.PRIMARY_FAINT;
  }

  private progressValue(): number {
    return Math.min(this.elapsedSeconds(), this.budgetSeconds());
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(this.statusLabel())
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.emphasisColor());
        Blank();
        Text(`目标 ${this.assignment.expectedMinutes} 分钟`)
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Text(this.timeValue())
        .width('100%')
        .fontSize(36)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.emphasisColor());

      Progress({ value: this.progressValue(), total: this.budgetSeconds(), type: ProgressType.Linear })
        .width('100%')
        .height(6)
        .color(this.emphasisColor())
        .backgroundColor(this.isOvertime() ? AppTheme.DANGER_SOFT :
          (this.isNearDeadline() ? AppTheme.WARNING_SOFT : AppTheme.PRIMARY_SOFT));
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.emphasisBackground())
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }
}
