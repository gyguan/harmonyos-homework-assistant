import { AppTheme } from '../../common/theme/AppTheme';
import { Assignment, AssignmentStatus } from '../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../domain/service/AssignmentStateMachine';
import { AssignmentDueDate } from '../../domain/service/AssignmentDueDate';

@Component
export struct AssignmentListItem {
  @Prop assignment: Assignment;
  @Prop selected: boolean = false;
  @Prop showChevron: boolean = true;
  @Prop interactive: boolean = true;
  @Prop selectionMode: boolean = false;
  @Prop selectionAvailable: boolean = true;
  onOpen: () => void = () => {};

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

  private subjectInitial(): string {
    return this.assignment.subject.length > 0 ? this.assignment.subject.substring(0, 1) : '作';
  }

  private timingText(): string {
    if (this.assignment.status === AssignmentStatus.PAUSED && this.assignment.elapsedSeconds > 0) {
      return `已用 ${Math.max(1, Math.round(this.assignment.elapsedSeconds / 60))} 分钟`;
    }
    if (this.assignment.elapsedSeconds > 0 && this.assignment.status !== AssignmentStatus.IN_PROGRESS) {
      return `实际 ${Math.max(1, Math.round(this.assignment.elapsedSeconds / 60))} 分钟`;
    }
    return `预计 ${this.assignment.expectedMinutes} 分钟`;
  }

  private deadlineText(): string {
    return AssignmentDueDate.displayText(this.assignment);
  }

  private accessibilityLabel(): string {
    let base = `${this.assignment.subject}，${this.assignment.title}，${this.deadlineText()}，${this.timingText()}，${AssignmentStateMachine.label(this.assignment.status)}`;
    if (!this.selectionMode) return base;
    if (!this.selectionAvailable) return `不可删除，${base}`;
    return `${this.selected ? '已选择' : '未选择'}，${base}`;
  }

  @Builder
  private LeadingIndicator() {
    if (this.selectionMode) {
      Stack() {
        Text(this.selectionAvailable && this.selected ? '✓' : (this.selectionAvailable ? '' : '—'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.selectionAvailable && this.selected ? AppTheme.TEXT_ON_PRIMARY : AppTheme.SUBTEXT)
          .textAlign(TextAlign.Center);
      }
      .width(38)
      .height(38)
      .alignContent(Alignment.Center)
      .backgroundColor(this.selectionAvailable && this.selected ? AppTheme.PRIMARY : AppTheme.SURFACE_EMPHASIS)
      .border({
        width: 1,
        color: this.selectionAvailable && this.selected ? AppTheme.PRIMARY : AppTheme.BORDER
      })
      .borderRadius(12);
    } else {
      Text(this.subjectInitial())
        .width(38)
        .height(38)
        .padding({ top: 9 })
        .textAlign(TextAlign.Center)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.PRIMARY)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(12);
    }
  }

  build() {
    Row({ space: 12 }) {
      this.LeadingIndicator();

      Column({ space: 4 }) {
        Text(this.assignment.title)
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(`${this.assignment.subject} · ${this.deadlineText()} · ${this.timingText()}`)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Column({ space: 5 }) {
        Text(AssignmentStateMachine.label(this.assignment.status))
          .maxLines(1)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor());
        if (this.showChevron && this.interactive) {
          Text('›').fontSize(20).fontColor(AppTheme.TERTIARY_TEXT);
        }
      }
      .alignItems(HorizontalAlign.End);
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding({ left: 12, right: 12, top: 11, bottom: 11 })
    .backgroundColor(this.selected ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
    .border({
      width: this.selected ? 1 : 0,
      color: this.selected ? AppTheme.PRIMARY : Color.Transparent
    })
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .enabled(this.interactive)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.accessibilityLabel())
    .onClick(() => {
      if (this.interactive) this.onOpen();
    });
  }
}
