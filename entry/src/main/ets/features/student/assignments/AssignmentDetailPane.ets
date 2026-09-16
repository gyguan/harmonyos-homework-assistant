import { AppTheme } from '../../../common/theme/AppTheme';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus, AssignmentType } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct AssignmentDetailPane {
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  onOpenStudy: (assignmentId: string) => void = (_assignmentId: string) => {};

  private assignment(): Assignment | null {
    let currentRevision = this.revision;
    if (currentRevision < 0 || this.assignmentId.length === 0) return null;
    return DefaultAssignmentRepository.instance.getCached(this.assignmentId);
  }

  private actionLabel(item: Assignment): string {
    if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.PAUSED) return '继续完成';
    if (item.status === AssignmentStatus.READY_TO_SUBMIT) return '去提交';
    if (item.status === AssignmentStatus.NEEDS_REWORK) return '继续订正';
    if (item.status === AssignmentStatus.SUBMITTED) return '查看提交状态';
    if (item.status === AssignmentStatus.COMPLETED) return '查看完成记录';
    return '开始作业';
  }

  private typeLabel(item: Assignment): string {
    return item.assignmentType === AssignmentType.EXTRA ? '课外作业' : '课内作业';
  }

  private canOpenStudy(item: Assignment): boolean {
    return item.status !== AssignmentStatus.COMPLETED;
  }

  @Builder
  private DetailRow(label: string, value: string) {
    Row({ space: 12 }) {
      Text(label).width(76).fontSize(13).fontColor(AppTheme.SUBTEXT);
      Text(value.length > 0 ? value : '未设置')
        .layoutWeight(1)
        .fontSize(14)
        .lineHeight(21)
        .fontColor(AppTheme.TEXT);
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 });
  }

  @Builder
  private EmptyState() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.doc_text')).fontSize(32).fontColor([AppTheme.TERTIARY_TEXT]);
      Text(this.assignmentId.length === 0 ? '选择左侧作业查看详情' : '这项作业暂时找不到')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text(this.assignmentId.length === 0 ? '详情会在这里显示，不需要离开作业列表。' : '作业可能已经删除或尚未同步完成。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 12, bottom: 24 });
  }

  build() {
    if (this.assignment() === null) {
      this.EmptyState();
    } else {
      Column({ space: 14 }) {
        Column({ space: 14 }) {
          Row({ space: 8 }) {
            Text(this.typeLabel(this.assignment()!))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.PRIMARY)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .borderRadius(AppTheme.CHIP_RADIUS);
            Text(this.assignment()!.subject)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.SUBTEXT);
            Blank();
            Text(AssignmentStateMachine.label(this.assignment()!.status))
              .fontSize(12)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');

          Text(this.assignment()!.title)
            .width('100%')
            .fontSize(AppTheme.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);

          Text(this.assignment()!.instruction)
            .width('100%')
            .fontSize(15)
            .lineHeight(23)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(AppTheme.SURFACE)
        .border({ width: 1, color: AppTheme.BORDER })
        .borderRadius(AppTheme.CARD_RADIUS);

        Column({ space: 0 }) {
          this.DetailRow('截止时间', this.assignment()!.dueText);
          Divider().color(AppTheme.DIVIDER);
          this.DetailRow('预计用时', `${this.assignment()!.expectedMinutes} 分钟`);
          Divider().color(AppTheme.DIVIDER);
          this.DetailRow('教材 / 页码', this.assignment()!.textbookRef);
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
        .backgroundColor(AppTheme.SURFACE)
        .border({ width: 1, color: AppTheme.BORDER })
        .borderRadius(AppTheme.CONTROL_RADIUS);

        if (this.assignment()!.reviewNote.length > 0) {
          Column({ space: 5 }) {
            Text('家长提醒')
              .width('100%')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.WARNING);
            Text(this.assignment()!.reviewNote)
              .width('100%')
              .fontSize(14)
              .lineHeight(21)
              .fontColor(AppTheme.TEXT);
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor(AppTheme.WARNING_SOFT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
        }

        Button(this.actionLabel(this.assignment()!), { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .enabled(this.canOpenStudy(this.assignment()!))
          .backgroundColor(this.canOpenStudy(this.assignment()!) ? AppTheme.PRIMARY : AppTheme.DISABLED)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => {
            if (this.canOpenStudy(this.assignment()!)) this.onOpenStudy(this.assignment()!.id);
          });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
  }
}
