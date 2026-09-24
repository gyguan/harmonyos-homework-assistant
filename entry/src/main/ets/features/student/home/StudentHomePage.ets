import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { CenteredTextBadge } from '../../../components/family/CenteredTextBadge';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { Assignment, AssignmentStatus, Subject } from '../../../domain/model/HomeworkModels';
import { StudentHomeViewModel } from './StudentHomeViewModel';

@Component
struct StudentTodayTaskCard {
  @Prop assignment: Assignment;
  @Prop emphasized: boolean = false;
  @Prop busy: boolean = false;
  onAction: (assignmentId: string) => void = (_assignmentId: string) => {};

  private subjectColor(): string {
    if (this.assignment.subject === Subject.CHINESE) return AppTheme.DANGER;
    if (this.assignment.subject === Subject.MATH) return AppTheme.PRIMARY;
    if (this.assignment.subject === Subject.ENGLISH) return '#7A3EF0';
    if (this.assignment.subject === Subject.SPORTS || this.assignment.subject === Subject.PRACTICE) {
      return AppTheme.SUCCESS;
    }
    return AppTheme.WARNING;
  }

  private subjectBackground(): string {
    if (this.assignment.subject === Subject.CHINESE) return AppTheme.DANGER_SOFT;
    if (this.assignment.subject === Subject.MATH) return AppTheme.PRIMARY_SOFT;
    if (this.assignment.subject === Subject.ENGLISH) return '#F1EBFF';
    if (this.assignment.subject === Subject.SPORTS || this.assignment.subject === Subject.PRACTICE) {
      return AppTheme.SUCCESS_SOFT;
    }
    return AppTheme.WARNING_SOFT;
  }

  private statusLabel(): string {
    if (this.assignment.status === AssignmentStatus.IN_PROGRESS) return '正在做';
    if (this.assignment.status === AssignmentStatus.PAUSED) return '已暂停';
    if (this.assignment.status === AssignmentStatus.NEEDS_REWORK) return '要订正';
    if (this.assignment.status === AssignmentStatus.OVERDUE) return '已逾期';
    if (this.assignment.status === AssignmentStatus.READY_TO_SUBMIT) return '待提交';
    return '未开始';
  }

  private actionLabel(): string {
    if (this.busy) return '请稍候…';
    if (this.assignment.status === AssignmentStatus.IN_PROGRESS ||
      this.assignment.status === AssignmentStatus.PAUSED) return '继续';
    if (this.assignment.status === AssignmentStatus.NEEDS_REWORK) return '去订正';
    if (this.assignment.status === AssignmentStatus.READY_TO_SUBMIT) return '去提交';
    return '开始';
  }

  private statusColor(): string {
    if (this.assignment.status === AssignmentStatus.NEEDS_REWORK ||
      this.assignment.status === AssignmentStatus.OVERDUE) return AppTheme.DANGER;
    if (this.assignment.status === AssignmentStatus.READY_TO_SUBMIT) return AppTheme.SUCCESS;
    if (this.assignment.status === AssignmentStatus.IN_PROGRESS ||
      this.assignment.status === AssignmentStatus.PAUSED) return AppTheme.PRIMARY;
    return AppTheme.SUBTEXT;
  }

  build() {
    Row({ space: 10 }) {
      CenteredTextBadge({
        badgeText: this.assignment.subject.substring(0, 1),
        badgeWidth: this.emphasized ? 46 : 40,
        badgeHeight: this.emphasized ? 46 : 40,
        badgeFontSize: this.emphasized ? 18 : 16,
        badgeRadius: 12,
        badgeBold: true,
        badgeForeground: this.subjectColor(),
        badgeBackground: this.subjectBackground()
      });

      Column({ space: 5 }) {
        Text(this.assignment.title)
          .width('100%')
          .fontSize(this.emphasized ? 18 : 16)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Row({ space: 5 }) {
          Text(this.statusLabel())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor());
          Text('·')
            .fontSize(12)
            .fontColor(AppTheme.TERTIARY_TEXT);
          Text(`${this.assignment.expectedMinutes} 分钟`)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Button(this.actionLabel(), { type: ButtonType.Normal })
        .width(this.emphasized ? 96 : 82)
        .height(AppTheme.MIN_TOUCH_TARGET)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.busy)
        .backgroundColor(this.busy ? AppTheme.DISABLED : AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .accessibilityText(`${this.actionLabel()}${this.assignment.title}`)
        .onClick(() => this.onAction(this.assignment.id));
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(this.emphasized ? 16 : 13)
    .backgroundColor(this.emphasized ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
    .border({ width: this.emphasized ? 1 : 0, color: this.emphasized ? AppTheme.PRIMARY : Color.Transparent })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityGroup(true)
    .accessibilityText(`${this.assignment.subject}，${this.assignment.title}，${this.statusLabel()}，预计${this.assignment.expectedMinutes}分钟`);

  }
}

@Component
export struct StudentHomePage {
  @Prop offlineMode: boolean = false;
  @Prop revision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private actionAssignmentId: string = '';
  @State private actionMessage: string = '';
  onOpenStudy: (assignmentId: string) => void = (_assignmentId: string) => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: StudentHomeViewModel =
    new StudentHomeViewModel(DefaultAssignmentRepository.instance);

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    if (currentRevision < 0) return [];
    return this.viewModel.todayActionableAssignments();
  }

  private remainingAssignments(): Assignment[] {
    let source = this.assignments();
    let result: Assignment[] = [];
    for (let index = 1; index < source.length; index++) result.push(source[index]);
    return result;
  }

  private canUsePadComposition(): boolean {
    return this.assignments().length > 1 &&
      LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.homeFocusSummaryRequirement());
  }

  private assignmentRenderKey(item: Assignment): string {
    return `${item.id}|${item.remoteVersion}|${item.subjectCode}|${item.subject}|${item.status}|${item.title}|${item.dueText}|${item.expectedMinutes}|${item.elapsedSeconds}|${item.reviewNote}`;
  }

  private async openAssignment(assignmentId: string): Promise<void> {
    if (this.actionAssignmentId.length > 0) return;
    let item = this.viewModel.assignment(assignmentId);
    if (item === null) return;
    this.actionMessage = '';
    if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.READY_TO_SUBMIT) {
      this.onOpenStudy(item.id);
      return;
    }

    this.actionAssignmentId = assignmentId;
    try {
      await this.viewModel.performAction(assignmentId, AssignmentAction.START);
      this.onStoreChanged();
      this.onOpenStudy(assignmentId);
    } catch {
      this.actionMessage = '暂时无法开始，请稍后再试';
    } finally {
      this.actionAssignmentId = '';
    }
  }

  @Builder
  private Header() {
    Row({ space: 11 }) {
      CenteredTextBadge({
        badgeText: this.viewModel.student().name.substring(0, 1),
        badgeWidth: 44,
        badgeHeight: 44,
        badgeFontSize: 18,
        badgeRadius: 22,
        badgeBold: true,
        badgeForeground: AppTheme.PRIMARY,
        badgeBackground: AppTheme.PRIMARY_SOFT
      });
      Column({ space: 2 }) {
        Text(`${this.viewModel.student().name}，今天先完成一项`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text(this.viewModel.dateLabel())
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%');
  }

  @Builder
  private OfflineBanner() {
    if (this.offlineMode) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.wifi_slash')).fontSize(17).fontColor([AppTheme.WARNING]);
        Text('当前离线，可以查看已缓存的今日作业。')
          .layoutWeight(1)
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.WARNING_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private EmptyState() {
    Row({ space: 11 }) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
        .fontSize(27)
        .fontColor([AppTheme.SUCCESS]);
      Column({ space: 3 }) {
        Text(this.viewModel.summary().total > 0 ? '今天的任务完成啦' : '今天没有安排任务')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('去休息一下，或者看看练习内容。')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SUCCESS_SOFT)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private TaskList(items: Assignment[]) {
    Column({ space: 10 }) {
      ForEach(items, (item: Assignment) => {
        StudentTodayTaskCard({
          assignment: item,
          busy: this.actionAssignmentId === item.id,
          onAction: (assignmentId: string) => { void this.openAssignment(assignmentId); }
        });
      }, (item: Assignment) => this.assignmentRenderKey(item));
    }
    .width('100%');
  }

  @Builder
  private TodayTasks() {
    Column({ space: 12 }) {
      Row() {
        Text('今天要做')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.assignments().length > 0) {
          Text(`${this.assignments().length} 项`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.assignments().length === 0) this.EmptyState();
      else this.TaskList(this.assignments());

      if (this.actionMessage.length > 0) {
        Text(this.actionMessage)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.WARNING);
      }
    }
    .width('100%');
  }

  @Builder
  private PhoneHome() {
    Column({ space: AppTheme.PHONE_SECTION_GAP }) {
      this.Header();
      this.OfflineBanner();
      this.TodayTasks();
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.HOME_READABLE_MAX_WIDTH })
    .padding({ left: AppTheme.PHONE_PAGE_PADDING, right: AppTheme.PHONE_PAGE_PADDING, top: 14, bottom: 20 });
  }

  @Builder
  private PadHome() {
    Column({ space: AppTheme.PHONE_SECTION_GAP }) {
      this.Header();
      this.OfflineBanner();
      Row({ space: AppTheme.SPLIT_PANE_GAP }) {
        Column({ space: 12 }) {
          Text('先做这项')
            .width('100%')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          StudentTodayTaskCard({
            assignment: this.assignments()[0],
            emphasized: true,
            busy: this.actionAssignmentId === this.assignments()[0].id,
            onAction: (assignmentId: string) => { void this.openAssignment(assignmentId); }
          });
        }
        .width(AppTheme.HOME_PRIMARY_MIN_WIDTH)
        .alignItems(HorizontalAlign.Start);

        Column({ space: 12 }) {
          Row() {
            Text('接下来')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT);
            Blank();
            Text(`${this.remainingAssignments().length} 项`)
              .fontSize(13)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');
          this.TaskList(this.remainingAssignments());
        }
        .layoutWeight(1)
        .constraintSize({ minWidth: AppTheme.HOME_SECONDARY_MIN_WIDTH })
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .alignItems(VerticalAlign.Top);

      if (this.actionMessage.length > 0) {
        Text(this.actionMessage).width('100%').fontSize(13).fontColor(AppTheme.WARNING);
      }
    }
    .width('100%')
    .constraintSize({ maxWidth: AppTheme.HOME_PAD_CONTENT_MAX_WIDTH })
    .padding({ left: AppTheme.PAGE_PADDING_WIDE, right: AppTheme.PAGE_PADDING_WIDE, top: 18, bottom: 24 });
  }

  build() {
    Scroll() {
      Column() {
        if (this.canUsePadComposition()) this.PadHome();
        else this.PhoneHome();
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
