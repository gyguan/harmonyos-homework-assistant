import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import {
  AssignmentDateFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentCalendarPanel } from './AssignmentCalendarPanel';
import { AssignmentDetailPane } from './AssignmentDetailPane';
import { AssignmentFilterDialog } from './AssignmentFilterDialog';
import { StudentAssignmentsViewModel } from './StudentAssignmentsViewModel';

@Component
export struct StudentAssignmentsPage {
  @Prop revision: number = 0;
  @State private refreshRevision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private selectedAssignmentId: string = '';

  @State private typeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private subjectCode: string = 'ALL';
  @State private dateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;
  @State private draftTypeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private draftSubjectCode: string = 'ALL';
  @State private draftDateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;
  @State private querying: boolean = false;
  @State private calendarMode: boolean = false;
  @State private selectedCalendarDayEpochMs: number = Date.now();
  @State private calendarMonthEpochMs: number = Date.now();

  @State private needHandlingAssignments: Assignment[] = [];
  @State private notStartedAssignments: Assignment[] = [];
  @State private submittedAssignments: Assignment[] = [];
  @State private completedAssignments: Assignment[] = [];
  @State private visibleTotal: number = 0;
  @State private totalCount: number = 0;

  onOpenDetail: (assignmentId: string) => void = (_assignmentId: string) => {};
  onOpenStudy: (assignmentId: string) => void = (_assignmentId: string) => {};

  private readonly viewModel: StudentAssignmentsViewModel =
    new StudentAssignmentsViewModel(DefaultAssignmentRepository.instance);

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: AssignmentFilterDialog({
      typeFilter: $draftTypeFilter,
      dateFilter: $draftDateFilter,
      subjectCode: $draftSubjectCode,
      onQuery: (typeFilter: AssignmentTypeFilter, dateFilter: AssignmentDateFilter, subjectCode: string) => {
        void this.applyFilters(typeFilter, dateFilter, subjectCode);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  aboutToAppear(): void {
    this.rebuildView();
    void this.refresh();
  }

  private async refresh(): Promise<void> {
    await this.viewModel.refresh();
    this.refreshRevision++;
    this.rebuildView();
  }

  private canUseMasterDetail(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.assignmentMasterDetailRequirement());
  }

  private rebuildView(): void {
    let currentRevision = this.revision + this.refreshRevision;
    if (currentRevision < 0) return;
    this.totalCount = this.viewModel.allCount();
    this.rebuildResults();
  }

  private rebuildResults(): void {
    if (this.calendarMode && this.dateFilter === AssignmentDateFilter.CUSTOM) {
      this.applyItems(this.viewModel.assignmentsOnDay(
        this.typeFilter, this.subjectCode, this.selectedCalendarDayEpochMs));
      return;
    }
    this.applyItems(this.viewModel.assignments(this.typeFilter, this.subjectCode, this.dateFilter));
  }

  private calendarAssignments(): Assignment[] {
    let currentRevision = this.revision + this.refreshRevision;
    if (currentRevision < 0) return [];
    return this.viewModel.calendarAssignments(this.typeFilter, this.subjectCode);
  }

  private padExtraAssignments(): Assignment[] {
    let currentRevision = this.revision + this.refreshRevision;
    if (currentRevision < 0) return [];
    let source = this.viewModel.calendarAssignments(AssignmentTypeFilter.EXTRA, 'ALL');
    let active: Assignment[] = [];
    let completed: Assignment[] = [];
    for (let item of source) {
      if (item.status === AssignmentStatus.COMPLETED) completed.push(item);
      else active.push(item);
    }
    return active.length > 0 ? active : completed;
  }

  private applyItems(items: Assignment[]): void {
    let needHandling: Assignment[] = [];
    let notStarted: Assignment[] = [];
    let submitted: Assignment[] = [];
    let completed: Assignment[] = [];

    for (let item of items) {
      if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.PAUSED ||
        item.status === AssignmentStatus.NEEDS_REWORK || item.status === AssignmentStatus.OVERDUE ||
        item.status === AssignmentStatus.READY_TO_SUBMIT) {
        needHandling.push(item);
      } else if (item.status === AssignmentStatus.NOT_STARTED) {
        notStarted.push(item);
      } else if (item.status === AssignmentStatus.SUBMITTED) {
        submitted.push(item);
      } else if (item.status === AssignmentStatus.COMPLETED) {
        completed.push(item);
      }
    }

    this.visibleTotal = items.length;
    this.needHandlingAssignments = needHandling;
    this.notStartedAssignments = notStarted;
    this.submittedAssignments = submitted;
    this.completedAssignments = completed;
    this.syncSelectedAssignment(items);
  }

  private syncSelectedAssignment(items: Assignment[]): void {
    for (let item of items) {
      if (item.id === this.selectedAssignmentId) return;
    }
    this.selectedAssignmentId = items.length > 0 ? items[0].id : '';
  }

  private openAssignment(assignmentId: string): void {
    if (this.canUseMasterDetail() && !this.calendarMode) {
      this.selectedAssignmentId = assignmentId;
    } else {
      this.onOpenDetail(assignmentId);
    }
  }

  private isSelected(assignmentId: string): boolean {
    return this.canUseMasterDetail() && !this.calendarMode && this.selectedAssignmentId === assignmentId;
  }

  private openFilterDialog(): void {
    if (this.querying) return;
    this.draftTypeFilter = this.typeFilter;
    this.draftSubjectCode = this.subjectCode;
    this.draftDateFilter = this.dateFilter === AssignmentDateFilter.CUSTOM ?
      AssignmentDateFilter.ALL : this.dateFilter;
    this.filterDialogController.open();
  }

  private async applyFilters(typeFilter: AssignmentTypeFilter,
    dateFilter: AssignmentDateFilter, subjectCode: string): Promise<void> {
    if (this.querying) return;
    this.querying = true;

    this.draftTypeFilter = typeFilter;
    this.draftDateFilter = dateFilter;
    this.draftSubjectCode = subjectCode;
    this.typeFilter = typeFilter;
    this.dateFilter = dateFilter;
    this.subjectCode = subjectCode;
    this.calendarMode = false;
    this.filterDialogController.close();

    try {
      let items = await this.viewModel.query(typeFilter, subjectCode, dateFilter);
      this.applyItems(items);
    } finally {
      this.querying = false;
    }
  }

  private showCalendar(): void {
    if (this.calendarMode) return;
    this.calendarMode = true;
    this.selectedCalendarDayEpochMs = Date.now();
    this.calendarMonthEpochMs = this.selectedCalendarDayEpochMs;
    this.dateFilter = AssignmentDateFilter.CUSTOM;
    this.rebuildResults();
  }

  private showList(): void {
    if (!this.calendarMode) return;
    this.calendarMode = false;
    if (this.dateFilter === AssignmentDateFilter.CUSTOM) {
      this.dateFilter = AssignmentDateFilter.ALL;
      this.draftDateFilter = AssignmentDateFilter.ALL;
    }
    this.rebuildResults();
  }

  private selectCalendarDay(dayEpochMs: number): void {
    this.selectedCalendarDayEpochMs = dayEpochMs;
    this.dateFilter = AssignmentDateFilter.CUSTOM;
    this.applyItems(this.viewModel.assignmentsOnDay(this.typeFilter, this.subjectCode, dayEpochMs));
  }

  private hasActiveFilters(): boolean {
    return this.typeFilter !== AssignmentTypeFilter.ALL || this.subjectCode !== 'ALL' ||
      this.dateFilter !== AssignmentDateFilter.ALL;
  }

  private typeLabel(value: AssignmentTypeFilter): string {
    if (value === AssignmentTypeFilter.SCHOOL) return '课内';
    if (value === AssignmentTypeFilter.EXTRA) return '课外';
    return '全部';
  }

  private dateLabel(value: AssignmentDateFilter): string {
    if (value === AssignmentDateFilter.TODAY) return '今天';
    if (value === AssignmentDateFilter.TOMORROW) return '明天';
    if (value === AssignmentDateFilter.THIS_WEEK) return '本周';
    if (value === AssignmentDateFilter.UNDATED) return '未定';
    if (value === AssignmentDateFilter.CUSTOM) {
      let selected = new Date(this.selectedCalendarDayEpochMs);
      return `${selected.getMonth() + 1}月${selected.getDate()}日`;
    }
    return '全部日期';
  }

  private subjectLabel(value: string): string {
    if (value === 'CHINESE') return '语文';
    if (value === 'MATH') return '数学';
    if (value === 'ENGLISH') return '英语';
    if (value === 'OTHER') return '其他';
    return '全部科目';
  }

  @Builder
  private ViewModeButton(label: string, active: boolean, action: () => void) {
    Button(label, { type: ButtonType.Normal })
      .height(AppTheme.MIN_TOUCH_TARGET)
      .padding({ left: 13, right: 13 })
      .borderRadius(AppTheme.CHIP_RADIUS)
      .fontSize(13)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(active ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)
      .fontColor(active ? AppTheme.PRIMARY : AppTheme.TEXT)
      .onClick(action);
  }

  @Builder
  private ViewModeToggle() {
    Row({ space: 4 }) {
      this.ViewModeButton('列表', !this.calendarMode, () => this.showList());
      this.ViewModeButton('日历', this.calendarMode, () => this.showCalendar());
    }
    .padding(3)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private FilterEntry(label: string, value: string, active: boolean) {
    Column({ space: 3 }) {
      Text(label).fontSize(11).fontColor(AppTheme.TERTIARY_TEXT);
      Row({ space: 3 }) {
        Text(value)
          .fontSize(13)
          .fontWeight(active ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(active ? AppTheme.PRIMARY : AppTheme.TEXT);
        Text('⌄').fontSize(11).fontColor(active ? AppTheme.PRIMARY : AppTheme.SUBTEXT);
      }
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${label}：${value}，打开筛选`)
    .onClick(() => this.openFilterDialog());
  }

  @Builder
  private FilterBar() {
    Row() {
      this.FilterEntry('类型', this.typeLabel(this.typeFilter), this.typeFilter !== AssignmentTypeFilter.ALL);
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      this.FilterEntry('截止', this.dateLabel(this.dateFilter), this.dateFilter !== AssignmentDateFilter.ALL);
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      this.FilterEntry('科目', this.subjectLabel(this.subjectCode), this.subjectCode !== 'ALL');
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      Text(this.querying ? '查询中…' : (this.hasActiveFilters() ? '筛选中' : '筛选'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.hasActiveFilters() ? AppTheme.PRIMARY : AppTheme.TEXT)
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .padding({ left: 14, right: 14 })
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText('打开筛选面板')
        .onClick(() => this.openFilterDialog());
    }
    .width('100%')
    .height(58)
    .padding({ left: 8, right: 8 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private NeedHandlingSection() {
    if (this.needHandlingAssignments.length > 0) {
      Column({ space: 9 }) {
        Row() {
          Column({ space: 2 }) {
            Text('需要处理').fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text('进行中、待订正、逾期或待提交').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
          Text(`${this.needHandlingAssignments.length}`)
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%');
        Column({ space: 6 }) {
          ForEach(this.needHandlingAssignments, (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: this.isSelected(item.id),
              showChevron: !this.canUseMasterDetail() || this.calendarMode,
              onOpen: () => this.openAssignment(item.id)
            });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private NotStartedSection() {
    if (this.notStartedAssignments.length > 0) {
      Column({ space: 9 }) {
        Row() {
          Column({ space: 2 }) {
            Text('待开始').fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text('还没有开始的作业').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
          Text(`${this.notStartedAssignments.length}`)
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%');
        Column({ space: 6 }) {
          ForEach(this.notStartedAssignments, (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: this.isSelected(item.id),
              showChevron: !this.canUseMasterDetail() || this.calendarMode,
              onOpen: () => this.openAssignment(item.id)
            });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private SubmittedSection() {
    if (this.submittedAssignments.length > 0) {
      Column({ space: 9 }) {
        Row() {
          Column({ space: 2 }) {
            Text('已提交').fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text('等待家长确认').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
          Text(`${this.submittedAssignments.length}`)
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%');
        Column({ space: 6 }) {
          ForEach(this.submittedAssignments, (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: this.isSelected(item.id),
              showChevron: !this.canUseMasterDetail() || this.calendarMode,
              onOpen: () => this.openAssignment(item.id)
            });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private CompletedSection() {
    if (this.completedAssignments.length > 0) {
      Column({ space: 9 }) {
        Row() {
          Column({ space: 2 }) {
            Text('已完成').fontSize(17).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
            Text('已经完成并验收').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
          }
          .alignItems(HorizontalAlign.Start);
          Blank();
          Text(`${this.completedAssignments.length}`)
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%');
        Column({ space: 6 }) {
          ForEach(this.completedAssignments, (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: this.isSelected(item.id),
              showChevron: !this.canUseMasterDetail() || this.calendarMode,
              onOpen: () => this.openAssignment(item.id)
            });
          }, (item: Assignment) => item.id);
        }
        .width('100%');
      }
      .width('100%');
    }
  }

  @Builder
  private EmptyState() {
    if (this.visibleTotal === 0) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.checkmark_square')).fontSize(30).fontColor([AppTheme.TERTIARY_TEXT]);
        Text(this.totalCount === 0 ? '暂时没有作业' :
          (this.calendarMode ? '这一天没有安排任务' : '当前筛选下没有作业'))
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(this.calendarMode ? '选择其他日期，或切回列表查看全部任务。' : '打开筛选面板调整条件后重新查询。')
          .fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding({ top: 30, bottom: 30 });
    }
  }

  @Builder
  private AssignmentSections() {
    Column({ space: 22 }) {
      Row() {
        Text(this.calendarMode ? `${this.dateLabel(AssignmentDateFilter.CUSTOM)}任务` :
          (this.hasActiveFilters() ? '筛选结果' : '全部作业'))
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.visibleTotal} 项`).fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      this.NeedHandlingSection();
      this.NotStartedSection();
      this.SubmittedSection();
      this.CompletedSection();
      this.EmptyState();
    }
    .width('100%');
  }

  @Builder
  private ListContent() {
    Column({ space: 18 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('我的作业').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(this.calendarMode ? '按日期查看课内、课外任务和完成情况。' : '通过筛选快速找到要完成的任务。')
            .fontSize(13).fontColor(AppTheme.SUBTEXT).maxLines(2);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        this.ViewModeToggle();
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      this.FilterBar();
      if (this.calendarMode) {
        AssignmentCalendarPanel({
          assignments: this.calendarAssignments(),
          selectedDayEpochMs: $selectedCalendarDayEpochMs,
          monthEpochMs: $calendarMonthEpochMs,
          onSelectDay: (dayEpochMs: number) => this.selectCalendarDay(dayEpochMs)
        });
      }
      this.AssignmentSections();
    }
    .width('100%');
  }

  @Builder
  private AssignmentDetailSidePane() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('作业详情')
            .fontSize(AppTheme.SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('点击左侧作业即可切换，状态与操作保持同一数据源。')
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%');

      Scroll() {
        Column() {
          AssignmentDetailPane({
            assignmentId: this.selectedAssignmentId,
            revision: this.revision + this.refreshRevision,
            onOpenStudy: (assignmentId: string) => this.onOpenStudy(assignmentId)
          });
        }
        .width('100%')
        .padding({ bottom: 12 });
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private PadExtraAssignmentsPane() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('课外任务')
            .fontSize(AppTheme.SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('阅读、运动、实践等任务独立汇总，和学校作业仍共用 Assignment。')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(18)
            .fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Text(`${this.padExtraAssignments().length} 项`).fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.padExtraAssignments().length === 0) {
        Column({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(28).fontColor([AppTheme.TERTIARY_TEXT]);
          Text('暂无课外任务').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('家长布置的课外任务会出现在这里。').fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .padding({ top: 34, bottom: 34 });
      } else {
        Scroll() {
          Column({ space: 7 }) {
            ForEach(this.padExtraAssignments(), (item: Assignment) => {
              AssignmentListItem({
                assignment: item,
                showChevron: true,
                onOpen: () => this.onOpenDetail(item.id)
              });
            }, (item: Assignment) => item.id);
          }
          .width('100%')
          .padding({ bottom: 12 });
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off);
      }
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private AssignmentListPage() {
    Scroll() {
      Column() {
        Column() {
          this.ListContent();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.ASSIGNMENT_LIST_READABLE_MAX_WIDTH })
        .padding(AppTheme.PAGE_PADDING);
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

  @Builder
  private AssignmentMasterDetail() {
    Row({ space: AppTheme.SPLIT_PANE_GAP }) {
      Scroll() {
        Column() {
          this.ListContent();
        }
        .width('100%')
        .padding({ top: 4, bottom: 16 });
      }
      .width(AppTheme.SPLIT_PRIMARY_MIN_WIDTH)
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);

      Column() {
        if (this.calendarMode) {
          this.PadExtraAssignmentsPane();
        } else {
          this.AssignmentDetailSidePane();
        }
      }
      .layoutWeight(1)
      .height('100%')
      .constraintSize({ minWidth: AppTheme.SPLIT_SECONDARY_MIN_WIDTH })
      .padding(AppTheme.CARD_PADDING)
      .backgroundColor(AppTheme.SURFACE_SUBTLE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CARD_RADIUS)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppTheme.ASSIGNMENT_MASTER_DETAIL_MAX_WIDTH })
    .alignItems(VerticalAlign.Top)
    .padding({ left: AppTheme.PAGE_PADDING_WIDE, right: AppTheme.PAGE_PADDING_WIDE, top: 18, bottom: 20 });
  }

  build() {
    Column() {
      if (this.canUseMasterDetail()) {
        this.AssignmentMasterDetail();
      } else {
        this.AssignmentListPage();
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = ResponsiveContext.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
