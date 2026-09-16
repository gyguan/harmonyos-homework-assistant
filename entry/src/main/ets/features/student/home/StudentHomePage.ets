import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus, AssignmentType } from '../../../domain/model/HomeworkModels';
import { StudentHomeViewModel } from './StudentHomeViewModel';

@Component
export struct StudentHomePage {
  @Prop offlineMode: boolean = false;
  @Prop revision: number = 0;
  @State private refreshRevision: number = 0;
  @State private availableWidthVp: number = 390;
  onOpenStudy: (assignmentId: string) => void = () => {};

  private readonly viewModel: StudentHomeViewModel =
    new StudentHomeViewModel(DefaultAssignmentRepository.instance);

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

  private nextAssignment(): Assignment | null {
    let currentRevision = this.touchRevision();
    return this.viewModel.nextAssignment();
  }

  private canUsePadComposition(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.homeFocusSummaryRequirement());
  }

  private dueLabel(assignment: Assignment): string {
    if (assignment.dueText.length > 0) return assignment.dueText;
    if (assignment.dueAtEpochMs <= 0) return '待确认截止时间';
    let due = new Date(assignment.dueAtEpochMs);
    let minute = due.getMinutes() < 10 ? `0${due.getMinutes()}` : `${due.getMinutes()}`;
    return `${due.getMonth() + 1}月${due.getDate()}日 ${due.getHours()}:${minute}`;
  }

  @Builder
  private Header() {
    Row() {
      Column({ space: 3 }) {
        Text(`你好，${this.viewModel.student().name}`)
          .fontSize(AppTheme.PHONE_PAGE_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text(`${this.viewModel.student().grade} · ${this.viewModel.student().className}`)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .alignItems(HorizontalAlign.Start);
      Blank();
      Text(this.viewModel.dateLabel())
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%');
  }

  @Builder
  private OfflineBanner() {
    if (this.offlineMode) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.wifi_slash')).fontSize(17).fontColor([AppTheme.WARNING]);
        Text('当前离线，正在使用已缓存的作业。')
          .layoutWeight(1)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.WARNING_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private TodayProgress() {
    Column({ space: 9 }) {
      Row() {
        Text('今日进度')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.viewModel.summary().total > 0) {
          Text(`${this.viewModel.summary().completed}/${this.viewModel.summary().total}`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
        } else {
          Text('暂无结构化今日任务').fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');
      Progress({
        value: this.viewModel.summary().completed,
        total: this.viewModel.summary().total > 0 ? this.viewModel.summary().total : 1,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(7)
        .color(AppTheme.PRIMARY)
        .backgroundColor(AppTheme.PRIMARY_SOFT);
      if (this.viewModel.summary().undated > 0) {
        Text(`${this.viewModel.summary().undated} 项历史作业尚无结构化截止时间，仍会保留在任务列表中。`)
          .width('100%')
          .fontSize(11)
          .lineHeight(17)
          .fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private AttentionBanner() {
    if (this.viewModel.attentionCount() > 0) {
      Row({ space: 9 }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill')).fontSize(18).fontColor([AppTheme.DANGER]);
        Text(`${this.viewModel.attentionCount()} 项作业需要优先处理`)
          .layoutWeight(1)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 11, bottom: 11 })
      .backgroundColor(AppTheme.DANGER_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private NextAssignmentHero() {
    if (this.nextAssignment() === null) {
      Row({ space: 11 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(25).fontColor([AppTheme.SUCCESS]);
        Column({ space: 4 }) {
          Text('现在没有待完成作业')
            .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('可以查看全部作业，或休息一下。').fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding(AppTheme.PHONE_CARD_PADDING)
      .backgroundColor(AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.PHONE_CARD_RADIUS);
    } else {
      Column({ space: 11 }) {
        Row() {
          Row({ space: 6 }) {
            Text(this.nextAssignment()!.subject)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.PRIMARY);
            if (this.nextAssignment()!.assignmentType === AssignmentType.EXTRA) {
              Text('课外')
                .fontSize(10)
                .fontColor(AppTheme.PRIMARY)
                .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                .backgroundColor(AppTheme.PRIMARY_SOFT)
                .borderRadius(AppTheme.CHIP_RADIUS);
            }
          }
          Blank();
          Text(this.dueLabel(this.nextAssignment()!)).fontSize(11).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
        Text(this.nextAssignment()!.title)
          .width('100%')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        Text(this.nextAssignment()!.instruction)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
        if (this.nextAssignment()!.status === AssignmentStatus.NEEDS_REWORK &&
          this.nextAssignment()!.reviewNote.length > 0) {
          Text(`家长提醒：${this.nextAssignment()!.reviewNote}`)
            .width('100%')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(AppTheme.DANGER)
            .padding(9)
            .backgroundColor(AppTheme.DANGER_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS);
        }
        Row() {
          Text(this.nextAssignment()!.textbookRef)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(`预计 ${this.nextAssignment()!.expectedMinutes} 分钟`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.WARNING);
        }
        .width('100%');
        Button(this.viewModel.actionLabel(this.nextAssignment()!), { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.onOpenStudy(this.nextAssignment()!.id));
      }
      .width('100%')
      .padding(AppTheme.PHONE_CARD_PADDING)
      .backgroundColor(AppTheme.SURFACE)
      .borderRadius(AppTheme.PHONE_CARD_RADIUS);
    }
  }

  @Builder
  private RemainingItem(item: Assignment) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(item.subject).fontSize(11).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
          Text(this.dueLabel(item)).fontSize(10).fontColor(AppTheme.SUBTEXT);
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
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([AppTheme.TERTIARY_TEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .padding({ left: 12, right: 10, top: 10, bottom: 10 })
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${item.subject}，${item.title}`)
    .onClick(() => this.onOpenStudy(item.id));
  }

  @Builder
  private RemainingAssignments() {
    if (this.viewModel.remainingAssignments().length > 0) {
      Column({ space: 9 }) {
        Row() {
          Text('今天还要做')
            .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Blank();
          Text(`${this.viewModel.remainingAssignments().length} 项`).fontSize(11).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
        Column({ space: 7 }) {
          ForEach(this.viewModel.remainingAssignments(), (item: Assignment) => {
            this.RemainingItem(item);
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private PadSummaryEmpty() {
    if (this.viewModel.attentionCount() === 0 && this.viewModel.remainingAssignments().length === 0) {
      Column({ space: 6 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(24).fontColor([AppTheme.SUCCESS]);
        Text('今天余下安排已清空')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('核心任务完成后，可以休息一下。').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .backgroundColor(AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.PHONE_CARD_RADIUS);
    }
  }

  @Builder
  private PhoneHome() {
    Column({ space: AppTheme.PHONE_SECTION_GAP }) {
      this.Header();
      this.OfflineBanner();
      this.TodayProgress();
      this.AttentionBanner();
      this.NextAssignmentHero();
      this.RemainingAssignments();
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.HOME_READABLE_MAX_WIDTH })
    .padding({ left: AppTheme.PHONE_PAGE_PADDING, right: AppTheme.PHONE_PAGE_PADDING, top: 14, bottom: 20 });
  }

  @Builder
  private PadHome() {
    Row({ space: AppTheme.SPLIT_PANE_GAP }) {
      Column({ space: AppTheme.PHONE_SECTION_GAP }) {
        this.Header();
        this.OfflineBanner();
        this.TodayProgress();
        this.NextAssignmentHero();
      }
      .layoutWeight(1)
      .constraintSize({ minWidth: AppTheme.HOME_PRIMARY_MIN_WIDTH })
      .alignItems(HorizontalAlign.Start);

      Column({ space: AppTheme.PHONE_SECTION_GAP }) {
        this.AttentionBanner();
        this.RemainingAssignments();
        this.PadSummaryEmpty();
      }
      .width(AppTheme.HOME_SECONDARY_MIN_WIDTH)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.HOME_PAD_CONTENT_MAX_WIDTH })
    .alignItems(VerticalAlign.Top)
    .padding({ left: AppTheme.PAGE_PADDING_WIDE, right: AppTheme.PAGE_PADDING_WIDE, top: 18, bottom: 24 });
  }

  build() {
    Scroll() {
      Column() {
        if (this.canUsePadComposition()) {
          this.PadHome();
        } else {
          this.PhoneHome();
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .onAreaChange((_oldValue, newValue) => {
        this.availableWidthVp = ResponsiveContext.areaLengthToVp(newValue.width, this.availableWidthVp);
      });
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .backgroundColor(AppTheme.BACKGROUND)
    .scrollBar(BarState.Off);
  }
}
