import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { CenteredTextBadge } from '../../../components/family/CenteredTextBadge';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus, AssignmentType, Subject } from '../../../domain/model/HomeworkModels';
import { StudentHomeSubjectGroup, StudentHomeViewModel } from './StudentHomeViewModel';

@Component
struct StudentHomeMetricCard {
  @Prop value: string = '0';
  @Prop label: string = '';
  @Prop tone: string = 'primary';

  private toneColor(): string {
    if (this.tone === 'success') return AppTheme.SUCCESS;
    if (this.tone === 'warning') return AppTheme.WARNING;
    return AppTheme.PRIMARY;
  }

  private toneBackground(): string {
    if (this.tone === 'success') return AppTheme.SUCCESS_SOFT;
    if (this.tone === 'warning') return AppTheme.WARNING_SOFT;
    return AppTheme.PRIMARY_FAINT;
  }

  build() {
    Column({ space: 4 }) {
      Text(this.value)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.toneColor());
      Text(this.label)
        .fontSize(11)
        .fontColor(AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 82 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.toneBackground())
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }
}

@Component
struct StudentSubjectTaskGroupCard {
  @Prop group: StudentHomeSubjectGroup = new StudentHomeSubjectGroup('其他', Subject.OTHER, []);
  @Prop expanded: boolean = false;
  @Prop focusAssignmentId: string = '';
  onToggle: () => void = () => {};
  onOpenStudy: (assignmentId: string) => void = (_assignmentId: string) => {};

  private subjectColor(): string {
    if (this.group.subject === Subject.CHINESE) return AppTheme.DANGER;
    if (this.group.subject === Subject.MATH) return AppTheme.PRIMARY;
    if (this.group.subject === Subject.ENGLISH) return '#7A3EF0';
    if (this.group.subject === Subject.SPORTS || this.group.subject === Subject.PRACTICE) return AppTheme.SUCCESS;
    return AppTheme.WARNING;
  }

  private subjectBackground(): string {
    if (this.group.subject === Subject.CHINESE) return AppTheme.DANGER_SOFT;
    if (this.group.subject === Subject.MATH) return AppTheme.PRIMARY_SOFT;
    if (this.group.subject === Subject.ENGLISH) return '#F1EBFF';
    if (this.group.subject === Subject.SPORTS || this.group.subject === Subject.PRACTICE) return AppTheme.SUCCESS_SOFT;
    return AppTheme.WARNING_SOFT;
  }

  private statusLabel(item: Assignment): string {
    if (item.status === AssignmentStatus.IN_PROGRESS) return '进行中';
    if (item.status === AssignmentStatus.PAUSED) return '继续';
    if (item.status === AssignmentStatus.NEEDS_REWORK) return '待订正';
    if (item.status === AssignmentStatus.OVERDUE) return '逾期';
    if (item.status === AssignmentStatus.READY_TO_SUBMIT) return '待提交';
    return '待开始';
  }

  private actionLabel(item: Assignment): string {
    if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.PAUSED) return '继续';
    if (item.status === AssignmentStatus.NEEDS_REWORK) return '订正';
    if (item.status === AssignmentStatus.READY_TO_SUBMIT) return '提交';
    return '开始';
  }

  private statusColor(item: Assignment): string {
    if (item.status === AssignmentStatus.NEEDS_REWORK || item.status === AssignmentStatus.OVERDUE) return AppTheme.DANGER;
    if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.PAUSED) return AppTheme.PRIMARY;
    if (item.status === AssignmentStatus.READY_TO_SUBMIT) return AppTheme.SUCCESS;
    return AppTheme.WARNING;
  }

  private statusBackground(item: Assignment): string {
    if (item.status === AssignmentStatus.NEEDS_REWORK || item.status === AssignmentStatus.OVERDUE) return AppTheme.DANGER_SOFT;
    if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.PAUSED) return AppTheme.PRIMARY_SOFT;
    if (item.status === AssignmentStatus.READY_TO_SUBMIT) return AppTheme.SUCCESS_SOFT;
    return AppTheme.WARNING_SOFT;
  }

  @Builder
  private TaskRow(item: Assignment) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(item.title)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          if (item.assignmentType === AssignmentType.EXTRA) {
            Text('课外')
              .fontSize(9)
              .fontColor(AppTheme.PRIMARY)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .borderRadius(AppTheme.CHIP_RADIUS);
          }
        }
        .width('100%');
        Row({ space: 6 }) {
          Text(`预计 ${item.expectedMinutes} 分钟`)
            .fontSize(11)
            .fontColor(AppTheme.SUBTEXT);
          if (item.textbookRef.length > 0) {
            Text('·').fontSize(11).fontColor(AppTheme.TERTIARY_TEXT);
            Text(item.textbookRef)
              .fontSize(11)
              .fontColor(AppTheme.SUBTEXT)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis });
          }
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      if (item.id === this.focusAssignmentId) {
        Text(this.actionLabel(item))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor(AppTheme.PRIMARY)
          .borderRadius(AppTheme.CHIP_RADIUS);
      } else {
        Text(this.statusLabel(item))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(item))
          .padding({ left: 9, right: 9, top: 6, bottom: 6 })
          .backgroundColor(this.statusBackground(item))
          .borderRadius(AppTheme.CHIP_RADIUS);
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
          .fontColor([AppTheme.TERTIARY_TEXT]);
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 62 })
    .padding({ left: 12, right: 10, top: 10, bottom: 10 })
    .backgroundColor(item.id === this.focusAssignmentId ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
    .border({
      width: item.id === this.focusAssignmentId ? 1 : 0,
      color: item.id === this.focusAssignmentId ? AppTheme.PRIMARY : Color.Transparent
    })
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${this.group.subject}，${item.title}，${this.statusLabel(item)}`)
    .onClick(() => this.onOpenStudy(item.id));
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        CenteredTextBadge({
          badgeText: this.group.subject.substring(0, 1),
          badgeWidth: 40,
          badgeHeight: 40,
          badgeFontSize: 17,
          badgeRadius: 12,
          badgeBold: true,
          badgeForeground: this.subjectColor(),
          badgeBackground: this.subjectBackground()
        });
        Text(this.group.subject)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.group.items.length} 项`)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
        Text(this.expanded ? '⌃' : '⌄')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.expanded ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
      }
      .width('100%')
      .constraintSize({ minHeight: 58 })
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .accessibilityGroup(true)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(`${this.group.subject}，${this.group.items.length}项作业，${this.expanded ? '已展开' : '已收起'}`)
      .onClick(() => this.onToggle());

      if (this.expanded) {
        Divider().color(AppTheme.DIVIDER).margin({ left: 12, right: 12 });
        Column({ space: 7 }) {
          ForEach(this.group.items, (item: Assignment) => {
            this.TaskRow(item);
          }, (item: Assignment) => item.id);
        }
        .width('100%')
        .padding({ left: 8, right: 8, top: 8, bottom: 8 });
      }
    }
    .width('100%')
    .backgroundColor(AppTheme.SURFACE)
    .border({
      width: this.expanded ? 1 : 0,
      color: this.expanded ? AppTheme.PRIMARY : Color.Transparent
    })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }
}

@Component
export struct StudentHomePage {
  @Prop offlineMode: boolean = false;
  @Prop revision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private expandedSubjectKey: string = '';
  @State private subjectExpansionInitialized: boolean = false;
  onOpenStudy: (assignmentId: string) => void = () => {};

  private readonly viewModel: StudentHomeViewModel =
    new StudentHomeViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void {
    this.initializeSubjectExpansion();
  }

  private initializeSubjectExpansion(): void {
    if (this.subjectExpansionInitialized) return;
    let groups = this.viewModel.todaySubjectGroups();
    let next = this.viewModel.nextAssignment();
    if (next !== null) this.expandedSubjectKey = next.subject;
    else if (groups.length > 0) this.expandedSubjectKey = groups[0].key;
    this.subjectExpansionInitialized = true;
  }

  private touchRevision(): number {
    return this.revision;
  }

  private subjectGroups(): StudentHomeSubjectGroup[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.todaySubjectGroups();
  }

  private focusAssignmentId(): string {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return '';
    let next = this.viewModel.nextAssignment();
    return next === null ? '' : next.id;
  }

  private canUsePadComposition(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.homeFocusSummaryRequirement());
  }

  private toggleSubject(key: string): void {
    this.expandedSubjectKey = this.expandedSubjectKey === key ? '' : key;
  }

  @Builder
  private Header() {
    Row({ space: 11 }) {
      CenteredTextBadge({
        badgeText: this.viewModel.student().name.substring(0, 1),
        badgeWidth: 46,
        badgeHeight: 46,
        badgeFontSize: 18,
        badgeRadius: 23,
        badgeBold: true,
        badgeForeground: AppTheme.PRIMARY,
        badgeBackground: AppTheme.PRIMARY_SOFT
      });
      Column({ space: 2 }) {
        Text(this.viewModel.student().name)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text(`${this.viewModel.student().grade} · ${this.viewModel.student().className}`)
          .fontSize(11)
          .fontColor(AppTheme.SUBTEXT);
      }
      .alignItems(HorizontalAlign.Start);
      Blank();
      Text(this.viewModel.dateLabel())
        .fontSize(11)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%');
  }

  @Builder
  private OfflineBanner() {
    if (this.offlineMode) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.wifi_slash')).fontSize(17).fontColor([AppTheme.WARNING]);
        Text('当前离线，正在使用已缓存的今日作业。')
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
  private TodayOverview() {
    Column({ space: 11 }) {
      Row() {
        Text('今天概览')
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.viewModel.attentionCount() > 0) {
          Text(`${this.viewModel.attentionCount()} 项需优先处理`)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.DANGER)
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor(AppTheme.DANGER_SOFT)
            .borderRadius(AppTheme.CHIP_RADIUS);
        }
      }
      .width('100%');

      Row({ space: 8 }) {
        StudentHomeMetricCard({
          value: `${this.viewModel.todaySubjectCount()}`,
          label: '待办科目',
          tone: 'primary'
        });
        StudentHomeMetricCard({
          value: `${this.viewModel.todayPendingCount()}`,
          label: '待完成',
          tone: 'warning'
        });
        StudentHomeMetricCard({
          value: `${this.viewModel.todayExpectedMinutes()}`,
          label: '预计分钟',
          tone: 'success'
        });
      }
      .width('100%');
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private TodayScopeNote() {
    Row({ space: 8 }) {
      Text('i')
        .width(20)
        .height(20)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center)
        .padding({ top: 2 })
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(10);
      Text('首页只显示今天要做的任务，其他日期和未定时间作业请到「作业」页筛选。')
        .layoutWeight(1)
        .fontSize(11)
        .lineHeight(17)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding({ left: 11, right: 11, top: 9, bottom: 9 })
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private TodaySubjects() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('今天要做')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text('按学科完成，一次专注一个学科')
            .fontSize(11)
            .fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        if (this.subjectGroups().length > 0) {
          Text(`${this.viewModel.todaySubjectCount()} 科 · ${this.viewModel.todayPendingCount()} 项`)
            .fontSize(11)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.subjectGroups().length === 0) {
        Row({ space: 11 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(25)
            .fontColor([AppTheme.SUCCESS]);
          Column({ space: 3 }) {
            Text(this.viewModel.summary().total > 0 ? '今天要做的任务已完成' : '今天没有安排任务')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('其他日期的作业可以在「作业」页查看。')
              .fontSize(11)
              .fontColor(AppTheme.SUBTEXT);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .padding(AppTheme.PHONE_CARD_PADDING)
        .backgroundColor(AppTheme.SUCCESS_SOFT)
        .borderRadius(AppTheme.PHONE_CARD_RADIUS);
      } else {
        Column({ space: 10 }) {
          ForEach(this.subjectGroups(), (group: StudentHomeSubjectGroup) => {
            StudentSubjectTaskGroupCard({
              group: group,
              expanded: this.expandedSubjectKey === group.key,
              focusAssignmentId: this.focusAssignmentId(),
              onToggle: () => this.toggleSubject(group.key),
              onOpenStudy: (assignmentId: string) => this.onOpenStudy(assignmentId)
            });
          }, (group: StudentHomeSubjectGroup) => group.key);
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  @Builder
  private PhoneHome() {
    Column({ space: AppTheme.PHONE_SECTION_GAP }) {
      this.Header();
      this.OfflineBanner();
      this.TodayOverview();
      this.TodayScopeNote();
      this.TodaySubjects();
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
        this.TodayOverview();
        this.TodayScopeNote();
      }
      .width(AppTheme.HOME_SECONDARY_MIN_WIDTH)
      .alignItems(HorizontalAlign.Start);

      Column() {
        this.TodaySubjects();
      }
      .layoutWeight(1)
      .constraintSize({ minWidth: AppTheme.HOME_PRIMARY_MIN_WIDTH })
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
