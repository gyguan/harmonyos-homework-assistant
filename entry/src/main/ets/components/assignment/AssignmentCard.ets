import { AppTheme } from '../../common/theme/AppTheme';
import { Assignment, AssignmentStatus } from '../../domain/model/HomeworkModels';

@Component
export struct AssignmentCard {
  @Prop assignment: Assignment;

  private statusLabel(): string {
    switch (this.assignment.status) {
      case AssignmentStatus.IN_PROGRESS:
        return '进行中';
      case AssignmentStatus.SUBMITTED:
        return '已提交';
      case AssignmentStatus.COMPLETED:
        return '已完成';
      case AssignmentStatus.OVERDUE:
        return '已超时';
      default:
        return '未开始';
    }
  }

  private statusColor(): string {
    switch (this.assignment.status) {
      case AssignmentStatus.IN_PROGRESS:
        return AppTheme.WARNING;
      case AssignmentStatus.COMPLETED:
        return AppTheme.SUCCESS;
      case AssignmentStatus.OVERDUE:
        return AppTheme.DANGER;
      default:
        return AppTheme.SUBTEXT;
    }
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.assignment.subject)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(12)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 });
        Blank();
        Text(this.statusLabel())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor());
      }
      .width('100%');

      Text(this.assignment.title)
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Text(this.assignment.textbookRef)
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT)
        .maxLines(2);

      Text(this.assignment.dueText)
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER });
  }
}
