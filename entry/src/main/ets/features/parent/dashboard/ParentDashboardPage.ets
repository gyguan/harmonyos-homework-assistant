import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';
import { ParentHomeViewModel } from './ParentHomeViewModel';

@Component
export struct ParentDashboardPage {
  @Prop revision: number = 0;
  @State private refreshRevision: number = 0;
  @State private availableWidthVp: number = 390;
  onOpenImport: () => void = () => {};
  onOpenExtra: () => void = () => {};
  onOpenProgress: () => void = () => {};
  onOpenReview: (assignmentId: string) => void = (_assignmentId: string) => {};

  private readonly viewModel: ParentHomeViewModel =
    new ParentHomeViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void {
    void this.refresh();
  }

  private async refresh(): Promise<void> {
    await this.viewModel.refresh();
    this.refreshRevision++;
  }

  private touchRevision(): number {
    return this.revision + this.refreshRevision;
  }

  private canUseWideComposition(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.parentHomeRequirement());
  }

  private attentionAssignments(): Assignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.attentionAssignments();
  }

  private assignments(): Assignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.assignments();
  }

  private openAttention(item: Assignment): void {
    if (item.status === AssignmentStatus.SUBMITTED || item.status === AssignmentStatus.COMPLETED ||
      item.status === AssignmentStatus.NEEDS_REWORK) {
      this.onOpenReview(item.id);
    } else {
      this.onOpenProgress();
    }
  }

  @Builder
  private Header() {
    Column({ space: 3 }) {
      Text(`${this.viewModel.student().name} 的今天`)
        .fontSize(AppTheme.PHONE_PAGE_TITLE_SIZE)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text(`${this.viewModel.student().grade} · ${this.viewModel.student().className}`)
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private TodaySummary() {
    Column({ space: 9 }) {
      Row() {
        Column({ space: 2 }) {
          Text('今日完成').fontSize(12).fontColor(AppTheme.SUBTEXT);
          Row({ space: 5 }) {
            Text(`${this.viewModel.summary().completed}`)
              .fontSize(29).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
            Text(`/ ${this.viewModel.summary().total}`)
              .fontSize(13).fontColor(AppTheme.SUBTEXT).margin({ top: 9 });
          }
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        if (this.attentionAssignments().length > 0) {
          Text(`${this.attentionAssignments().length} 项需关注`)
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.DANGER)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.DANGER_SOFT)
            .borderRadius(AppTheme.CHIP_RADIUS);
        } else {
          Text('今天正常')
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS)
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .backgroundColor(AppTheme.SUCCESS_SOFT)
            .borderRadius(AppTheme.CHIP_RADIUS);
        }
      }
      .width('100%');
      Progress({
        value: this.viewModel.summary().completed,
        total: this.viewModel.summary().total > 0 ? this.viewModel.summary().total : 1,
        type: ProgressType.Linear
      })
        .width('100%').height(7).color(AppTheme.PRIMARY).backgroundColor(AppTheme.PRIMARY_SOFT);
      Text(this.viewModel.summary().total > 0 ? '只关注需要家长处理的事项，其余让孩子自己完成。' : '今天暂时没有结构化作业。')
        .width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
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
          Text('需要我处理').fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Blank();
          Text(`${this.attentionAssignments().length} 项`).fontSize(11).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
        Column({ space: 7 }) {
          ForEach(this.attentionAssignments(), (item: Assignment) => {
            Row({ space: 10 }) {
              Column({ space: 3 }) {
                Row({ space: 6 }) {
                  Text(item.subject).fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
                  Text(item.status === AssignmentStatus.SUBMITTED ? '待验收' : AssignmentStateMachine.label(item.status))
                    .fontSize(10)
                    .fontColor(item.status === AssignmentStatus.SUBMITTED ? AppTheme.WARNING : AppTheme.DANGER);
                }
                Text(item.title).width('100%').fontSize(14).fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start);
              SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([AppTheme.TERTIARY_TEXT]);
            }
            .width('100%')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 12, right: 10, top: 10, bottom: 10 })
            .backgroundColor(item.status === AssignmentStatus.SUBMITTED ? AppTheme.WARNING_SOFT : AppTheme.DANGER_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText(`${item.subject}，${item.title}，${AssignmentStateMachine.label(item.status)}`)
            .onClick(() => this.openAttention(item));
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private RecentSubmission() {
    if (this.viewModel.recentSubmitted() !== null) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(21).fontColor([AppTheme.SUCCESS]);
        Column({ space: 3 }) {
          Text('最近提交').fontSize(12).fontColor(AppTheme.SUBTEXT);
          Text(`${this.viewModel.recentSubmitted()!.subject} · ${this.viewModel.recentSubmitted()!.title}`)
            .width('100%').fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([AppTheme.TERTIARY_TEXT]);
      }
      .width('100%')
      .padding(13)
      .backgroundColor(AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('查看最近提交')
      .onClick(() => this.onOpenReview(this.viewModel.recentSubmitted()!.id));
    }
  }

  @Builder
  private ImportAction() {
    Row({ space: 11 }) {
      SymbolGlyph($r('sys.symbol.plus_square')).fontSize(22).fontColor([AppTheme.PRIMARY]);
      Column({ space: 2 }) {
        Text('导入老师作业').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text('截图或文字，整理后再确认发布').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([AppTheme.TERTIARY_TEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: 13, right: 13, top: 11, bottom: 11 })
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`给 ${this.viewModel.student().name} 导入老师作业`)
    .onClick(() => this.onOpenImport());
  }

  @Builder
  private ExtraAction() {
    Row({ space: 11 }) {
      SymbolGlyph($r('sys.symbol.add_circle')).fontSize(22).fontColor([AppTheme.SUCCESS]);
      Column({ space: 2 }) {
        Text('布置课外任务').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text('阅读、朗读、体育、实践或兴趣任务').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([AppTheme.TERTIARY_TEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding({ left: 13, right: 13, top: 11, bottom: 11 })
    .backgroundColor(AppTheme.SUCCESS_SOFT)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`给 ${this.viewModel.student().name} 布置课外任务`)
    .onClick(() => this.onOpenExtra());
  }

  @Builder
  private TodayAssignments() {
    Column({ space: 9 }) {
      Row() {
        Text('作业进度').fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text('查看全部').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 8, right: 4 })
          .onClick(() => this.onOpenProgress());
      }
      .width('100%');
      if (this.assignments().length === 0) {
        Text('还没有发布作业').width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT)
          .padding({ top: 18, bottom: 18 }).textAlign(TextAlign.Center);
      } else {
        Column({ space: 6 }) {
          ForEach(this.assignments(), (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              showChevron: true,
              onOpen: () => this.openAttention(item)
            });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  @Builder
  private SingleColumnHome() {
    Scroll() {
      Column() {
        Column({ space: AppTheme.PHONE_SECTION_GAP }) {
          this.Header();
          this.TodaySummary();
          this.AttentionSection();
          this.RecentSubmission();
          this.ImportAction();
          this.ExtraAction();
          this.TodayAssignments();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PARENT_HOME_READABLE_MAX_WIDTH })
        .padding({ left: AppTheme.PHONE_PAGE_PADDING, right: AppTheme.PHONE_PAGE_PADDING, top: 14, bottom: 20 });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off);
  }

  @Builder
  private WideHome() {
    Scroll() {
      Column({ space: 18 }) {
        this.Header();
        Row({ space: AppTheme.SPLIT_PANE_GAP }) {
          Column({ space: 16 }) {
            this.TodaySummary();
            this.TodayAssignments();
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
          Column({ space: 14 }) {
            this.AttentionSection();
            this.RecentSubmission();
            this.ImportAction();
            this.ExtraAction();
          }
          .width(AppTheme.PARENT_HOME_SECONDARY_MIN_WIDTH)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .alignItems(VerticalAlign.Top);
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.PARENT_HOME_PAD_CONTENT_MAX_WIDTH })
      .padding({ left: AppTheme.PAGE_PADDING_WIDE, right: AppTheme.PAGE_PADDING_WIDE, top: 18, bottom: 20 });
    }
    .width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off);
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
