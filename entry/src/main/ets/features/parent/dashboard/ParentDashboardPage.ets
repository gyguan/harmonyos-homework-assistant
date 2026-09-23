import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentMetricSummary } from '../../../components/assignment/AssignmentMetricSummary';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentDueDate } from '../../../domain/service/AssignmentDueDate';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';
import { ParentHomeViewModel } from './ParentHomeViewModel';

@Component
export struct ParentDashboardPage {
  @Prop revision: number = 0;
  @Prop activeStudentId: string = '';
  @State private availableWidthVp: number = 390;
  onOpenAssignment: () => void = () => {};
  onOpenInbox: () => void = () => {};
  onOpenVoice: () => void = () => {};
  onOpenProgress: () => void = () => {};
  onOpenReview: (assignmentId: string) => void = (_assignmentId: string) => {};

  private readonly viewModel: ParentHomeViewModel =
    new ParentHomeViewModel(DefaultAssignmentRepository.instance);

  private touchRevision(): number {
    return this.revision;
  }

  private canUseWideComposition(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.parentHomeRequirement());
  }

  private attentionAssignments(): Assignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.attentionAssignments();
  }

  private visibleAttentionAssignments(): Assignment[] {
    return this.attentionAssignments().slice(0, 3);
  }

  private assignments(): Assignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.assignments();
  }

  private todayAssignments(): Assignment[] {
    let result: Assignment[] = [];
    let todayStart = AssignmentDueDate.businessDayStart(Date.now());
    for (let item of this.assignments()) {
      if (AssignmentDueDate.dayStart(item) === todayStart) result.push(item);
    }
    return result;
  }

  private todayPendingCount(): number {
    let count = 0;
    for (let item of this.todayAssignments()) {
      if (item.status !== AssignmentStatus.SUBMITTED && item.status !== AssignmentStatus.COMPLETED) count++;
    }
    return count;
  }

  private todaySubmittedCount(): number {
    let count = 0;
    for (let item of this.todayAssignments()) {
      if (item.status === AssignmentStatus.SUBMITTED) count++;
    }
    return count;
  }

  private todayCompletedCount(): number {
    let count = 0;
    for (let item of this.todayAssignments()) {
      if (item.status === AssignmentStatus.COMPLETED) count++;
    }
    return count;
  }

  private openAttention(item: Assignment): void {
    if (item.status === AssignmentStatus.SUBMITTED ||
      item.status === AssignmentStatus.NEEDS_REWORK) {
      this.onOpenReview(item.id);
    } else {
      this.onOpenProgress();
    }
  }

  private assignmentRenderKey(item: Assignment): string {
    return `${item.id}|${item.remoteVersion}|${item.status}|${item.title}|${item.dueText}|${item.expectedMinutes}`;
  }

  @Builder
  private TodayOverview() {
    Column({ space: 12 }) {
      Row() {
        Text('今天的学习')
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.todayAssignments().length} 项`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      AssignmentMetricSummary({
        allCount: this.todayAssignments().length,
        pendingCount: this.todayPendingCount(),
        submittedCount: this.todaySubmittedCount(),
        completedCount: this.todayCompletedCount()
      });

      Row({ space: 10 }) {
        Progress({
          value: this.todayCompletedCount(),
          total: this.todayAssignments().length > 0 ? this.todayAssignments().length : 1,
          type: ProgressType.Linear
        })
          .layoutWeight(1)
          .height(6)
          .color(AppTheme.PRIMARY)
          .backgroundColor(AppTheme.PRIMARY_SOFT);

        Text(`已完成 ${this.todayCompletedCount()}/${this.todayAssignments().length}`)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private AttentionSection() {
    if (this.attentionAssignments().length > 0) {
      Column({ space: 9 }) {
        Row() {
          Text('需要我处理')
            .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Blank();
          Text(`${this.attentionAssignments().length} 项`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');

        Column({ space: 7 }) {
          ForEach(this.visibleAttentionAssignments(), (item: Assignment) => {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Row({ space: 6 }) {
                  Text(item.subject)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppTheme.PRIMARY);
                  Text(item.status === AssignmentStatus.SUBMITTED ?
                    '待验收' : AssignmentStateMachine.label(item.status))
                    .fontSize(13)
                    .fontColor(item.status === AssignmentStatus.SUBMITTED ?
                      AppTheme.WARNING : AppTheme.DANGER);
                }
                Text(item.title)
                  .width('100%')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);

              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(15)
                .fontColor([AppTheme.TERTIARY_TEXT]);
            }
            .width('100%')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 12, right: 10, top: 10, bottom: 10 })
            .backgroundColor(item.status === AssignmentStatus.SUBMITTED ?
              AppTheme.WARNING_SOFT : AppTheme.DANGER_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(`${item.subject}，${item.title}，${AssignmentStateMachine.label(item.status)}`)
            .onClick(() => this.openAttention(item));
          }, (item: Assignment) => this.assignmentRenderKey(item));
        }
        .width('100%');

        if (this.attentionAssignments().length > 3) {
          Text(`查看全部 ${this.attentionAssignments().length} 项`)
            .width('100%')
            .height(AppTheme.MIN_TOUCH_TARGET)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('查看全部需要处理的作业')
            .onClick(() => this.onOpenProgress());
        }
      }
      .width('100%');
    }
  }

  @Builder
  private CreateAssignmentAction() {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.plus_square'))
        .fontSize(24)
        .fontColor([AppTheme.PRIMARY]);

      Column({ space: 3 }) {
        Text('布置作业')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('输入文字 / 选择作业截图')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppTheme.TERTIARY_TEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: 72 })
    .padding({ left: 14, right: 12, top: 12, bottom: 12 })
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('布置作业，输入文字或选择作业截图')
    .onClick(() => this.onOpenAssignment());
  }

  @Builder
  private CreateVoiceAction() {
    Row({ space: 12 }) {
      Text('♪')
        .width(28)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center);

      Column({ space: 3 }) {
        Text('语音作业')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('本地文件 / 服务器文件夹')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([AppTheme.TERTIARY_TEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: 72 })
    .padding({ left: 14, right: 12, top: 12, bottom: 12 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('布置语音作业，本地文件或服务器文件夹')
    .onClick(() => this.onOpenVoice());
  }

  @Builder
  private AssignmentInboxAction() {
    Row({ space: 10 }) {
      Text('箱')
        .width(30)
        .height(30)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(9);

      Column({ space: 2 }) {
        Text('作业收件箱')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('查看导入和整理记录')
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([AppTheme.TERTIARY_TEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: 56 })
    .padding({ left: 12, right: 10, top: 9, bottom: 9 })
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('打开作业收件箱')
    .onClick(() => this.onOpenInbox());
  }

  @Builder
  private AssignmentActions() {
    Column({ space: 10 }) {
      Text('布置作业')
        .width('100%')
        .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      this.CreateAssignmentAction();
      this.CreateVoiceAction();

      Text('其他')
        .width('100%')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.SUBTEXT)
        .margin({ top: 4 });

      this.AssignmentInboxAction();
    }
    .width('100%');
  }

  @Builder
  private SingleColumnHome() {
    Scroll() {
      Column() {
        Column({ space: AppTheme.PHONE_SECTION_GAP }) {
          this.TodayOverview();
          this.AttentionSection();
          this.AssignmentActions();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PARENT_HOME_READABLE_MAX_WIDTH })
        .padding({
          left: AppTheme.PHONE_PAGE_PADDING,
          right: AppTheme.PHONE_PAGE_PADDING,
          top: 14,
          bottom: 20
        });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
  }

  @Builder
  private WideHome() {
    Scroll() {
      Column({ space: 20 }) {
        this.TodayOverview();

        if (this.attentionAssignments().length > 0) {
          Row({ space: AppTheme.SPLIT_PANE_GAP }) {
            Column() {
              this.AttentionSection();
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start);

            Column() {
              this.AssignmentActions();
            }
            .width(AppTheme.PARENT_HOME_SECONDARY_MIN_WIDTH)
            .alignItems(HorizontalAlign.Start);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          Column() {
            this.AssignmentActions();
          }
          .width(AppTheme.PARENT_HOME_SECONDARY_MIN_WIDTH)
          .alignItems(HorizontalAlign.Start);
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_HOME_PAD_CONTENT_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING_WIDE,
        right: AppTheme.PAGE_PADDING_WIDE,
        top: 20,
        bottom: 20
      });
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
  }

  build() {
    Column() {
      if (this.canUseWideComposition()) {
        this.WideHome();
      } else {
        this.SingleColumnHome();
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = LayoutPolicy.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
