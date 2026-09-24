import { AppTheme } from '../../../common/theme/AppTheme';
import { ActionButton } from '../../../components/action/ActionControls';
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
    if (item.status === AssignmentStatus.NEEDS_REWORK) return '去订正';
    if (item.status === AssignmentStatus.SUBMITTED) return '查看提交状态';
    return '开始作业';
  }

  private typeLabel(item: Assignment): string {
    return item.assignmentType === AssignmentType.EXTRA ? '课外作业' : '课内作业';
  }

  private canOpenStudy(item: Assignment): boolean {
    return item.status !== AssignmentStatus.COMPLETED;
  }

  @Builder
  private SectionTitle(title: string) {
    Text(title)
      .width('100%')
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.SUBTEXT);
  }

  @Builder
  private EmptyState() {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.doc_text')).fontSize(32).fontColor([AppTheme.TERTIARY_TEXT]);
      Text(this.assignmentId.length === 0 ? '选择左侧作业查看详情' : '这项作业暂时找不到')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      if (this.assignmentId.length > 0) {
        Text('作业可能已经删除或尚未同步完成。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private DetailContent() {
    Column({ space: 14 }) {
      Column({ space: 14 }) {
        Row({ space: 8 }) {
          Text(this.typeLabel(this.assignment()!))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .borderRadius(AppTheme.CHIP_RADIUS);
          Text(this.assignment()!.subject)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.SUBTEXT);
          Blank();
          Text(AssignmentStateMachine.label(this.assignment()!.status))
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');

        Text(this.assignment()!.title)
          .width('100%')
          .fontSize(AppTheme.PAGE_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);

        Row({ space: 8 }) {
          Text(this.assignment()!.dueText.length > 0 ? this.assignment()!.dueText : '未设置截止时间')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
          Text('·').fontSize(13).fontColor(AppTheme.TERTIARY_TEXT);
          Text(`预计 ${this.assignment()!.expectedMinutes} 分钟`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(AppTheme.SURFACE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CARD_RADIUS);

      if (this.assignment()!.reviewNote.length > 0) {
        Column({ space: 5 }) {
          Text('需要先订正')
            .width('100%')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.DANGER);
          Text(this.assignment()!.reviewNote)
            .width('100%')
            .fontSize(15)
            .lineHeight(22)
            .fontColor(AppTheme.TEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(15)
        .backgroundColor(AppTheme.DANGER_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      }

      Column({ space: 8 }) {
        this.SectionTitle('老师要求');
        Text(this.assignment()!.instruction.length > 0 ? this.assignment()!.instruction : '按课堂要求完成这项作业。')
          .width('100%')
          .fontSize(16)
          .lineHeight(24)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(AppTheme.SURFACE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CONTROL_RADIUS);

      if (this.assignment()!.textbookRef.length > 0) {
        Row({ space: 12 }) {
          Text('教材 / 页码').width(76).fontSize(13).fontColor(AppTheme.SUBTEXT);
          Text(this.assignment()!.textbookRef)
            .layoutWeight(1)
            .fontSize(14)
            .lineHeight(21)
            .fontColor(AppTheme.TEXT);
        }
        .width('100%')
        .padding(15)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      }

      if (this.assignment()!.resourceLabels.length > 0) {
        Column({ space: 10 }) {
          this.SectionTitle('老师资料');
          ForEach(this.assignment()!.resourceLabels, (label: string) => {
            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.doc_text'))
                .fontSize(18)
                .fontColor([AppTheme.PRIMARY]);
              Text(label)
                .layoutWeight(1)
                .fontSize(14)
                .lineHeight(21)
                .fontColor(AppTheme.TEXT);
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 });
          }, (label: string) => label);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(15)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ bottom: 14 });
  }

  build() {
    if (this.assignment() === null) {
      this.EmptyState();
    } else {
      Column({ space: 10 }) {
        Scroll() {
          this.DetailContent();
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off);

        if (this.canOpenStudy(this.assignment()!)) {
          ActionButton({
            label: this.actionLabel(this.assignment()!),
            onAction: (): void => this.onOpenStudy(this.assignment()!.id)
          })
          .width('100%');
        }
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start);
    }
  }
}
