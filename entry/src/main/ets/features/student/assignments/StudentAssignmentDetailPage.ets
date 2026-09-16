import { AppTheme } from '../../../common/theme/AppTheme';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus, AssignmentType } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct StudentAssignmentDetailPage {
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onOpenStudy: (assignmentId: string) => void = (_assignmentId: string) => {};

  private assignment(): Assignment | null {
    let currentRevision = this.revision;
    return DefaultAssignmentRepository.instance.getCached(this.assignmentId);
  }

  private actionLabel(item: Assignment): string {
    if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.PAUSED) return '继续完成';
    if (item.status === AssignmentStatus.READY_TO_SUBMIT) return '去提交';
    if (item.status === AssignmentStatus.NEEDS_REWORK) return '继续订正';
    return '开始作业';
  }

  private typeLabel(item: Assignment): string {
    return item.assignmentType === AssignmentType.EXTRA ? '课外作业' : '课内作业';
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
  private MissingState() {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(34)
        .fontColor([AppTheme.TERTIARY_TEXT]);
      Text('这项作业暂时找不到').fontSize(18).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Button('返回作业列表', { type: ButtonType.Normal })
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .onClick(() => this.onBack());
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 20, bottom: 32 });
  }

  @Builder
  private DetailContent() {
    Column({ space: 18 }) {
      Row() {
        Text('‹ 作业列表')
          .fontSize(14)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 4, right: 8 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('返回作业列表')
          .onClick(() => this.onBack());
        Blank();
      }
      .width('100%');

      if (this.assignment() === null) {
        this.MissingState();
      } else {
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
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.onOpenStudy(this.assignment()!.id));
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: 720 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: AppTheme.PAGE_PADDING, right: AppTheme.PAGE_PADDING, top: 12, bottom: 32 });
  }

  build() {
    Scroll() {
      Column() {
        this.DetailContent();
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
  }
}
