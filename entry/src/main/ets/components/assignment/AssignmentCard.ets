import { AppTheme } from '../../common/theme/AppTheme';
import { Assignment, AssignmentStatus } from '../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../domain/service/AssignmentStateMachine';

@Component
export struct AssignmentCard {
  @Prop assignment: Assignment;

  private statusLabel(): string {
    return AssignmentStateMachine.label(this.assignment.status);
  }

  private statusColor(): string {
    switch (this.assignment.status) {
      case AssignmentStatus.IN_PROGRESS:
      case AssignmentStatus.PAUSED:
      case AssignmentStatus.READY_TO_SUBMIT:
        return AppTheme.WARNING;
      case AssignmentStatus.SUBMITTED:
      case AssignmentStatus.COMPLETED:
        return AppTheme.SUCCESS;
      case AssignmentStatus.NEEDS_REWORK:
      case AssignmentStatus.OVERDUE:
        return AppTheme.DANGER;
      default:
        return AppTheme.SUBTEXT;
    }
  }

  private statusBackground(): string {
    switch (this.assignment.status) {
      case AssignmentStatus.IN_PROGRESS:
      case AssignmentStatus.PAUSED:
      case AssignmentStatus.READY_TO_SUBMIT:
        return AppTheme.WARNING_SOFT;
      case AssignmentStatus.SUBMITTED:
      case AssignmentStatus.COMPLETED:
        return AppTheme.SUCCESS_SOFT;
      case AssignmentStatus.NEEDS_REWORK:
      case AssignmentStatus.OVERDUE:
        return AppTheme.DANGER_SOFT;
      default:
        return AppTheme.SURFACE_EMPHASIS;
    }
  }

  private timeLabel(): string {
    if (this.assignment.status === AssignmentStatus.PAUSED) {
      let minutes = this.assignment.elapsedSeconds > 0 ? Math.max(1, Math.round(this.assignment.elapsedSeconds / 60)) : 0;
      return `已用 ${minutes} 分钟 · 预计 ${this.assignment.expectedMinutes} 分钟`;
    }
    if (this.assignment.elapsedSeconds > 0 && this.assignment.status !== AssignmentStatus.IN_PROGRESS) {
      let minutes = Math.max(1, Math.round(this.assignment.elapsedSeconds / 60));
      return `预计 ${this.assignment.expectedMinutes} 分钟 · 实际 ${minutes} 分钟`;
    }
    return `预计 ${this.assignment.expectedMinutes} 分钟`;
  }

  build() {
    Column({ space: AppTheme.ITEM_GAP }) {
      Row({ space: 8 }) {
        Text(this.assignment.subject)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(AppTheme.CHIP_RADIUS)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 });
        Blank();
        Text(this.statusLabel())
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor())
          .backgroundColor(this.statusBackground())
          .borderRadius(AppTheme.CHIP_RADIUS)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 });
      }
      .width('100%');

      Text(this.assignment.title)
        .width('100%')
        .fontSize(AppTheme.CARD_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .maxLines(2);

      Text(this.assignment.textbookRef)
        .width('100%')
        .fontSize(13)
        .lineHeight(19)
        .fontColor(AppTheme.SUBTEXT)
        .maxLines(2);

      if (this.assignment.status === AssignmentStatus.NEEDS_REWORK && this.assignment.reviewNote.length > 0) {
        Column({ space: 3 }) {
          Text('家长订正说明').width('100%').fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.DANGER);
          Text(this.assignment.reviewNote).width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.TEXT).maxLines(3);
        }.width('100%').padding(10).backgroundColor(AppTheme.DANGER_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
      }

      Row() {
        Text(`截至 ${this.assignment.dueText}`)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.TERTIARY_TEXT);
        Blank();
        Text(this.timeLabel())
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%');
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }
}
