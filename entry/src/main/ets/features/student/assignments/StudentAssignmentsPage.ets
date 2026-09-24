import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentFilterDialog } from '../../../components/assignment/AssignmentFilterDialog';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { SegmentedSelectionButton } from '../../../components/selection/SelectionControls';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentDateFilter, AssignmentTypeFilter } from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentDetailPane } from './AssignmentDetailPane';
import { StudentAssignmentsViewModel } from './StudentAssignmentsViewModel';

@Component
export struct StudentAssignmentsPage {
  @Prop revision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private selectedAssignmentId: string = '';

  @State private subjectCode: string = 'ALL';
  @State private draftSubjectCode: string = 'ALL';
  @State private allDates: boolean = false;
  @State private draftAllDates: boolean = false;
  @State private selectedCalendarDayEpochMs: number = Date.now();
  @State private draftSelectedDayEpochMs: number = Date.now();
  @State private querying: boolean = false;
  @State private historyExpanded: boolean = false;

  @State private needHandlingAssignments: Assignment[] = [];
  @State private notStartedAssignments: Assignment[] = [];
  @State private submittedAssignments: Assignment[] = [];
  @State private completedAssignments: Assignment[] = [];
  @State private visibleTotal: number = 0;
  @State private totalCount: number = 0;
  @State private snapshotRevision: number = -1;

  onOpenDetail: (assignmentId: string) => void = (_assignmentId: string) => {};
  onOpenStudy: (assignmentId: string) => void = (_assignmentId: string) => {};

  private readonly viewModel: StudentAssignmentsViewModel =
    new StudentAssignmentsViewModel(DefaultAssignmentRepository.instance);

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: AssignmentFilterDialog({
      allDates: $draftAllDates,
      selectedDayEpochMs: $draftSelectedDayEpochMs,
      subjectCode: $draftSubjectCode,
      onQuery: (allDates: boolean, selectedDayEpochMs: number, subjectCode: string) => {
        void this.applyFilters(allDates, selectedDayEpochMs, subjectCode);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  aboutToAppear(): void {
    this.rebuildView();
  }

  private canUseMasterDetail(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.assignmentMasterDetailRequirement());
  }

  private rebuildView(): void {
    let currentRevision = this.revision;
    if (currentRevision < 0) return;
    this.totalCount = this.viewModel.allCount();
    this.rebuildResults();
  }

  private rebuildResults(): void {
    if (this.allDates) {
      this.applyItems(this.viewModel.assignments(
        AssignmentTypeFilter.ALL, this.subjectCode, AssignmentDateFilter.ALL));
      return;
    }
    this.applyItems(this.viewModel.assignmentsOnDay(
      AssignmentTypeFilter.ALL, this.subjectCode, this.selectedCalendarDayEpochMs));
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
    this.snapshotRevision = this.revision;
    this.needHandlingAssignments = needHandling;
    this.notStartedAssignments = notStarted;
    this.submittedAssignments = submitted;
    this.completedAssignments = completed;
    this.syncSelectedAssignment(items);
  }

  private currentVisibleAssignments(): Assignment[] {
    if (this.snapshotRevision === this.revision) {
      let items: Assignment[] = [];
      for (let item of this.needHandlingAssignments) items.push(item);
      for (let item of this.notStartedAssignments) items.push(item);
      for (let item of this.submittedAssignments) items.push(item);
      for (let item of this.completedAssignments) items.push(item);
      return items;
    }
    if (this.allDates) {
      return this.viewModel.assignments(
        AssignmentTypeFilter.ALL, this.subjectCode, AssignmentDateFilter.ALL);
    }
    return this.viewModel.assignmentsOnDay(
      AssignmentTypeFilter.ALL, this.subjectCode, this.selectedCalendarDayEpochMs);
  }

  private currentNeedHandlingAssignments(): Assignment[] {
    if (this.snapshotRevision === this.revision) return this.needHandlingAssignments;
    let result: Assignment[] = [];
    for (let item of this.currentVisibleAssignments()) {
      if (item.status === AssignmentStatus.IN_PROGRESS || item.status === AssignmentStatus.PAUSED ||
        item.status === AssignmentStatus.NEEDS_REWORK || item.status === AssignmentStatus.OVERDUE ||
        item.status === AssignmentStatus.READY_TO_SUBMIT) result.push(item);
    }
    return result;
  }

  private currentNotStartedAssignments(): Assignment[] {
    if (this.snapshotRevision === this.revision) return this.notStartedAssignments;
    let result: Assignment[] = [];
    for (let item of this.currentVisibleAssignments()) {
      if (item.status === AssignmentStatus.NOT_STARTED) result.push(item);
    }
    return result;
  }

  private currentSubmittedAssignments(): Assignment[] {
    if (this.snapshotRevision === this.revision) return this.submittedAssignments;
    let result: Assignment[] = [];
    for (let item of this.currentVisibleAssignments()) {
      if (item.status === AssignmentStatus.SUBMITTED) result.push(item);
    }
    return result;
  }

  private currentCompletedAssignments(): Assignment[] {
    if (this.snapshotRevision === this.revision) return this.completedAssignments;
    let result: Assignment[] = [];
    for (let item of this.currentVisibleAssignments()) {
      if (item.status === AssignmentStatus.COMPLETED) result.push(item);
    }
    return result;
  }

  private currentTodoAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.currentNeedHandlingAssignments()) result.push(item);
    for (let item of this.currentNotStartedAssignments()) result.push(item);
    return result;
  }

  private currentHistoryAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.currentSubmittedAssignments()) result.push(item);
    for (let item of this.currentCompletedAssignments()) result.push(item);
    return result;
  }

  private currentVisibleTotal(): number {
    if (this.snapshotRevision === this.revision) return this.visibleTotal;
    return this.currentVisibleAssignments().length;
  }

  private currentTotalCount(): number {
    if (this.snapshotRevision === this.revision) return this.totalCount;
    return this.viewModel.allCount();
  }

  private assignmentRenderKey(item: Assignment): string {
    return `${item.id}|${item.remoteVersion}|${item.status}|${item.title}|${item.dueText}|${item.expectedMinutes}|${item.elapsedSeconds}|${item.reviewNote}`;
  }

  private syncSelectedAssignment(items: Assignment[]): void {
    for (let item of items) {
      if (item.id === this.selectedAssignmentId) return;
    }
    this.selectedAssignmentId = items.length > 0 ? items[0].id : '';
  }

  private openAssignment(assignmentId: string): void {
    if (this.canUseMasterDetail()) this.selectedAssignmentId = assignmentId;
    else this.onOpenDetail(assignmentId);
  }

  private isSelected(assignmentId: string): boolean {
    return this.canUseMasterDetail() && this.selectedAssignmentId === assignmentId;
  }

  private openFilterDialog(): void {
    if (this.querying) return;
    this.draftAllDates = this.allDates;
    this.draftSelectedDayEpochMs = this.selectedCalendarDayEpochMs;
    this.draftSubjectCode = this.subjectCode;
    this.filterDialogController.open();
  }

  private async applyFilters(allDates: boolean, selectedDayEpochMs: number, subjectCode: string): Promise<void> {
    if (this.querying) return;
    this.querying = true;
    this.draftAllDates = allDates;
    this.draftSelectedDayEpochMs = selectedDayEpochMs;
    this.draftSubjectCode = subjectCode;
    this.allDates = allDates;
    this.selectedCalendarDayEpochMs = selectedDayEpochMs;
    this.subjectCode = subjectCode;
    this.filterDialogController.close();
    try {
      let items = allDates ?
        await this.viewModel.query(AssignmentTypeFilter.ALL, subjectCode, AssignmentDateFilter.ALL) :
        await this.viewModel.queryOnDay(subjectCode, selectedDayEpochMs);
      this.applyItems(items);
    } finally {
      this.querying = false;
    }
  }

  private isSelectedDayToday(): boolean {
    let now = new Date();
    let today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    let selected = new Date(this.selectedCalendarDayEpochMs);
    let selectedStart = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate()).getTime();
    return selectedStart === today;
  }

  private selectToday(): void {
    if (this.querying) return;
    void this.applyFilters(false, Date.now(), this.subjectCode);
  }

  private selectAllDates(): void {
    if (this.querying) return;
    void this.applyFilters(true, this.selectedCalendarDayEpochMs, this.subjectCode);
  }

  private selectSubjectCode(value: string): void {
    if (this.querying || value === this.subjectCode) return;
    void this.applyFilters(this.allDates, this.selectedCalendarDayEpochMs, value);
  }

  private dateLabel(): string {
    if (this.allDates) return '全部日期';
    let selected = new Date(this.selectedCalendarDayEpochMs);
    let month = selected.getMonth() + 1;
    let day = selected.getDate();
    let monthText = month < 10 ? `0${month}` : `${month}`;
    let dayText = day < 10 ? `0${day}` : `${day}`;
    return `${selected.getFullYear()}-${monthText}-${dayText}`;
  }

  private subjectLabel(value: string): string {
    if (value === 'CHINESE') return '语文';
    if (value === 'MATH') return '数学';
    if (value === 'ENGLISH') return '英语';
    if (value === 'OTHER') return '其他';
    return '全部科目';
  }

  @Builder
  private QuickFilterBar() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('日期')
          .width(42)
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT);
        SegmentedSelectionButton({
          label: '今天',
          selected: !this.allDates && this.isSelectedDayToday(),
          onSelect: () => this.selectToday()
        })
          .layoutWeight(1);
        SegmentedSelectionButton({
          label: '全部',
          selected: this.allDates,
          onSelect: () => this.selectAllDates()
        })
          .layoutWeight(1);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Row({ space: 8 }) {
        Text('科目')
          .width(42)
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUBTEXT);
        SegmentedSelectionButton({
          label: '全部',
          selected: this.subjectCode === 'ALL',
          onSelect: () => this.selectSubjectCode('ALL')
        })
          .layoutWeight(1);
        SegmentedSelectionButton({
          label: '语文',
          selected: this.subjectCode === 'CHINESE',
          onSelect: () => this.selectSubjectCode('CHINESE')
        })
          .layoutWeight(1);
        SegmentedSelectionButton({
          label: '数学',
          selected: this.subjectCode === 'MATH',
          onSelect: () => this.selectSubjectCode('MATH')
        })
          .layoutWeight(1);
        SegmentedSelectionButton({
          label: '英语',
          selected: this.subjectCode === 'ENGLISH',
          onSelect: () => this.selectSubjectCode('ENGLISH')
        })
          .layoutWeight(1);
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      Row({ space: 8 }) {
        Text(`更多筛选：${this.dateLabel()} · ${this.subjectLabel(this.subjectCode)}`)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.TERTIARY_TEXT);
        Text(this.querying ? '查询中…' : '调整')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 10, right: 2 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('调整日期和科目筛选')
          .onClick(() => this.openFilterDialog());
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 10 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private TodoSection() {
    if (this.currentTodoAssignments().length > 0) {
      Column({ space: 6 }) {
        ForEach(this.currentTodoAssignments(), (item: Assignment) => {
          AssignmentListItem({
            assignment: item,
            selected: this.isSelected(item.id),
            showChevron: !this.canUseMasterDetail(),
            onOpen: () => this.openAssignment(item.id)
          });
        }, (item: Assignment) => this.assignmentRenderKey(item));
      }
      .width('100%');
    }
  }

  @Builder
  private HistorySection() {
    if (this.currentHistoryAssignments().length > 0) {
      Column({ space: 9 }) {
        Row({ space: 8 }) {
          Text(`已提交 / 已完成 · ${this.currentHistoryAssignments().length}`)
            .layoutWeight(1)
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.SUBTEXT);
          Text(this.historyExpanded ? '收起' : '查看')
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
            .fontColor(AppTheme.PRIMARY);
          Text(this.historyExpanded ? '⌃' : '⌄')
            .fontSize(16)
            .fontColor(AppTheme.PRIMARY);
        }
        .width('100%')
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .padding({ left: 12, right: 12 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(this.historyExpanded ? '收起已提交和已完成作业' : '查看已提交和已完成作业')
        .onClick(() => this.historyExpanded = !this.historyExpanded);

        if (this.historyExpanded) {
          Column({ space: 6 }) {
            ForEach(this.currentHistoryAssignments(), (item: Assignment) => {
              AssignmentListItem({
                assignment: item,
                selected: this.isSelected(item.id),
                showChevron: !this.canUseMasterDetail(),
                onOpen: () => this.openAssignment(item.id)
              });
            }, (item: Assignment) => this.assignmentRenderKey(item));
          }
          .width('100%');
        }
      }
      .width('100%');
    }
  }

  @Builder
  private EmptyState() {
    if (this.currentVisibleTotal() === 0) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.checkmark_square')).fontSize(30).fontColor([AppTheme.TERTIARY_TEXT]);
        Text(this.currentTotalCount() === 0 ? '暂时没有作业' : '这一天没有安排任务')
          .fontSize(AppTheme.CARD_TITLE_SIZE).lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      }
      .width('100%')
      .padding({ top: 30, bottom: 30 });
    }
  }

  @Builder
  private AssignmentSections() {
    Column({ space: 22 }) {
      Row() {
        Text(this.allDates ? '全部作业' : `${this.dateLabel()} 任务`)
          .fontSize(AppTheme.SECTION_TITLE_SIZE).lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.currentVisibleTotal()} 项`).fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      this.TodoSection();
      this.HistorySection();
      this.EmptyState();
    }
    .width('100%');
  }

  @Builder
  private ListContent() {
    Column({ space: 18 }) {
      this.QuickFilterBar();
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
        }
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%');

      Column() {
        AssignmentDetailPane({
          assignmentId: this.selectedAssignmentId,
          revision: this.revision,
          onOpenStudy: (assignmentId: string) => this.onOpenStudy(assignmentId)
        });
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
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
        .constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })
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
        this.AssignmentDetailSidePane();
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
    .constraintSize({ maxWidth: AppTheme.CONTENT_WIDE_MAX_WIDTH })
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
