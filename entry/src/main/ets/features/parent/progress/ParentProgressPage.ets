import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentFilterDialog } from '../../../components/assignment/AssignmentFilterDialog';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { FilterSummaryEntry } from '../../../components/selection/SelectionControls';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import {
  AssignmentDateFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { ParentReviewPane } from '../review/ParentReviewPane';
import { ParentProgressViewModel } from './ParentProgressViewModel';

enum ParentProgressStatusFilter {
  ALL = 'ALL',
  ATTENTION = 'ATTENTION',
  SUBMITTED = 'SUBMITTED',
  COMPLETED = 'COMPLETED'
}

@Component
export struct ParentProgressPage {
  @Prop revision: number = 0;
  @State private refreshRevision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private selectedAssignmentId: string = '';

  @State private typeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private dateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;
  @State private subjectCode: string = 'ALL';
  @State private statusFilter: ParentProgressStatusFilter = ParentProgressStatusFilter.ALL;
  @State private draftTypeFilter: AssignmentTypeFilter = AssignmentTypeFilter.ALL;
  @State private draftDateFilter: AssignmentDateFilter = AssignmentDateFilter.ALL;
  @State private draftSubjectCode: string = 'ALL';
  @State private visibleAssignments: Assignment[] = [];
  @State private snapshotRevision: number = -1;
  @State private querying: boolean = false;

  onOpenReview: (assignmentId: string) => void = (_assignmentId: string) => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: ParentProgressViewModel =
    new ParentProgressViewModel(DefaultAssignmentRepository.instance);

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
  }

  private canUseReviewPane(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.parentProgressReviewRequirement());
  }

  private statuses(): AssignmentStatus[] {
    if (this.statusFilter === ParentProgressStatusFilter.ATTENTION) {
      return [AssignmentStatus.OVERDUE, AssignmentStatus.NEEDS_REWORK];
    }
    if (this.statusFilter === ParentProgressStatusFilter.SUBMITTED) return [AssignmentStatus.SUBMITTED];
    if (this.statusFilter === ParentProgressStatusFilter.COMPLETED) return [AssignmentStatus.COMPLETED];
    return [];
  }

  private rebuildView(): void {
    let currentRevision = this.revision + this.refreshRevision;
    if (currentRevision < 0) return;
    this.applyItems(this.viewModel.assignments(
      this.typeFilter, this.subjectCode, this.dateFilter, this.statuses()));
  }

  private applyItems(items: Assignment[]): void {
    this.visibleAssignments = items.slice();
    this.snapshotRevision = this.revision + this.refreshRevision;
    let stillVisible = false;
    for (let item of items) if (item.id === this.selectedAssignmentId) stillVisible = true;
    if (!stillVisible) this.selectedAssignmentId = items.length > 0 ? items[0].id : '';
  }

  private currentVisibleAssignments(): Assignment[] {
    let currentRevision = this.revision + this.refreshRevision;
    if (this.snapshotRevision === currentRevision) return this.visibleAssignments;
    return this.viewModel.assignments(
      this.typeFilter, this.subjectCode, this.dateFilter, this.statuses());
  }

  private assignmentRenderKey(item: Assignment): string {
    return `${item.id}|${item.remoteVersion}|${item.status}|${item.title}|${item.dueText}|${item.expectedMinutes}|${item.elapsedSeconds}|${item.reviewNote}`;
  }

  private openFilterDialog(): void {
    if (this.querying) return;
    this.draftTypeFilter = this.typeFilter;
    this.draftDateFilter = this.dateFilter;
    this.draftSubjectCode = this.subjectCode;
    this.filterDialogController.open();
  }

  private async applyFilters(typeFilter: AssignmentTypeFilter,
    dateFilter: AssignmentDateFilter, subjectCode: string): Promise<void> {
    if (this.querying) return;
    this.draftTypeFilter = typeFilter;
    this.draftDateFilter = dateFilter;
    this.draftSubjectCode = subjectCode;
    this.typeFilter = typeFilter;
    this.dateFilter = dateFilter;
    this.subjectCode = subjectCode;
    this.filterDialogController.close();
    await this.queryCurrent();
  }

  private async queryCurrent(): Promise<void> {
    if (this.querying) return;
    this.querying = true;
    try {
      let items = await this.viewModel.query(
        this.typeFilter, this.subjectCode, this.dateFilter, this.statuses());
      this.applyItems(items);
    } finally {
      this.querying = false;
    }
  }

  private chooseStatus(value: ParentProgressStatusFilter): void {
    if (this.statusFilter === value || this.querying) return;
    this.statusFilter = value;
    void this.queryCurrent();
  }

  private openAssignment(item: Assignment): void {
    if (this.canUseReviewPane()) this.selectedAssignmentId = item.id;
    else this.onOpenReview(item.id);
  }

  private isSelected(item: Assignment): boolean {
    return this.canUseReviewPane() && this.selectedAssignmentId === item.id;
  }

  private attentionCount(): number {
    let count = 0;
    for (let item of this.viewModel.assignments(
      AssignmentTypeFilter.ALL, 'ALL', AssignmentDateFilter.ALL)) {
      if (item.status === AssignmentStatus.OVERDUE || item.status === AssignmentStatus.NEEDS_REWORK) count++;
    }
    return count;
  }

  private allCount(): number {
    return this.viewModel.assignments(
      AssignmentTypeFilter.ALL, 'ALL', AssignmentDateFilter.ALL).length;
  }

  private submittedCount(): number {
    return this.viewModel.assignments(
      AssignmentTypeFilter.ALL, 'ALL', AssignmentDateFilter.ALL, [AssignmentStatus.SUBMITTED]).length;
  }

  private completedCount(): number {
    return this.viewModel.assignments(
      AssignmentTypeFilter.ALL, 'ALL', AssignmentDateFilter.ALL, [AssignmentStatus.COMPLETED]).length;
  }

  private hasActiveFilters(): boolean {
    return this.typeFilter !== AssignmentTypeFilter.ALL || this.dateFilter !== AssignmentDateFilter.ALL ||
      this.subjectCode !== 'ALL';
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
    return '全部日期';
  }

  private subjectLabel(value: string): string {
    if (value === 'CHINESE') return '语文';
    if (value === 'MATH') return '数学';
    if (value === 'ENGLISH') return '英语';
    if (value === 'OTHER') return '其他';
    return '全部科目';
  }

  private statusLabel(value: ParentProgressStatusFilter): string {
    if (value === ParentProgressStatusFilter.ATTENTION) return '需关注';
    if (value === ParentProgressStatusFilter.SUBMITTED) return '待验收';
    if (value === ParentProgressStatusFilter.COMPLETED) return '已完成';
    return '全部状态';
  }

  @Builder
  private FilterBar() {
    Row() {
      FilterSummaryEntry({
        label: '类型', value: this.typeLabel(this.typeFilter),
        active: this.typeFilter !== AssignmentTypeFilter.ALL,
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '截止', value: this.dateLabel(this.dateFilter),
        active: this.dateFilter !== AssignmentDateFilter.ALL,
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '科目', value: this.subjectLabel(this.subjectCode), active: this.subjectCode !== 'ALL',
        onOpen: () => this.openFilterDialog()
      });
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
  private StatusMetricCard(label: string, value: number, filter: ParentProgressStatusFilter, tone: string) {
    Column({ space: 5 }) {
      Text(`${value}`)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(tone === 'attention' ? AppTheme.DANGER :
          tone === 'review' ? AppTheme.WARNING :
            tone === 'done' ? AppTheme.SUCCESS : AppTheme.PRIMARY);
      Text(label)
        .fontSize(11)
        .fontColor(AppTheme.SUBTEXT);
    }
    .layoutWeight(1)
    .constraintSize({ minHeight: 76 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(tone === 'attention' ? AppTheme.DANGER_SOFT :
      tone === 'review' ? AppTheme.WARNING_SOFT :
        tone === 'done' ? AppTheme.SUCCESS_SOFT : AppTheme.PRIMARY_FAINT)
    .border({
      width: this.statusFilter === filter ? 2 : 0,
      color: this.statusFilter === filter ?
        (tone === 'attention' ? AppTheme.DANGER :
          tone === 'review' ? AppTheme.WARNING :
            tone === 'done' ? AppTheme.SUCCESS : AppTheme.PRIMARY) : AppTheme.BORDER
    })
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${label} ${value} 项，点击筛选`)
    .onClick(() => this.chooseStatus(filter));
  }

  @Builder
  private StatusSummary() {
    Row({ space: 8 }) {
      this.StatusMetricCard('全部', this.allCount(), ParentProgressStatusFilter.ALL, 'primary');
      this.StatusMetricCard('需关注', this.attentionCount(), ParentProgressStatusFilter.ATTENTION, 'attention');
      this.StatusMetricCard('待验收', this.submittedCount(), ParentProgressStatusFilter.SUBMITTED, 'review');
      this.StatusMetricCard('已完成', this.completedCount(), ParentProgressStatusFilter.COMPLETED, 'done');
    }
    .width('100%');
  }

  @Builder
  private ListContent() {
    Column({ space: 16 }) {
      Column({ space: 3 }) {
        Text('作业进度').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Text(`${this.viewModel.student().name} · ${this.viewModel.student().grade} · ${this.viewModel.student().className}`)
          .fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%').alignItems(HorizontalAlign.Start);

      this.StatusSummary();
      this.FilterBar();

      Row() {
        Text(this.querying ? '查询中…' :
          `${this.typeLabel(this.typeFilter)} · ${this.dateLabel(this.dateFilter)} · ${this.subjectLabel(this.subjectCode)} · ${this.statusLabel(this.statusFilter)}`)
          .fontSize(12).fontColor(AppTheme.SUBTEXT);
        Blank();
        Text(`${this.currentVisibleAssignments().length} 项`).fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.currentVisibleAssignments().length === 0) {
        Column({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(28).fontColor([AppTheme.TERTIARY_TEXT]);
          Text('当前筛选下没有作业').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('可以调整类型、截止、科目或状态筛选。').fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%').padding({ top: 30, bottom: 30 });
      } else {
        Column({ space: 7 }) {
          ForEach(this.currentVisibleAssignments(), (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: this.isSelected(item),
              showChevron: !this.canUseReviewPane(),
              onOpen: () => this.openAssignment(item)
            });
          }, (item: Assignment) => this.assignmentRenderKey(item));
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  @Builder
  private SingleColumnProgress() {
    Scroll() {
      Column() {
        Column() {
          this.ListContent();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.PARENT_PROGRESS_READABLE_MAX_WIDTH })
        .padding(AppTheme.PAGE_PADDING);
      }
      .width('100%').alignItems(HorizontalAlign.Center);
    }
    .width('100%').height('100%').align(Alignment.TopStart).scrollBar(BarState.Off);
  }

  @Builder
  private ProgressReviewSplit() {
    Row({ space: AppTheme.SPLIT_PANE_GAP }) {
      Scroll() {
        Column() { this.ListContent(); }
          .width('100%').padding({ top: 4, bottom: 16 });
      }
      .width(AppTheme.PARENT_PROGRESS_LIST_MIN_WIDTH)
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);

      Column({ space: 10 }) {
        Column({ space: 2 }) {
          Text('作业详情').fontSize(AppTheme.SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        }
        .width('100%').alignItems(HorizontalAlign.Start);
        Scroll() {
          Column() {
            ParentReviewPane({
              assignmentId: this.selectedAssignmentId,
              revision: this.revision + this.refreshRevision,
              onReviewed: () => {
                this.refreshRevision++;
                this.rebuildView();
                this.onStoreChanged();
              }
            });
          }
          .width('100%').padding({ bottom: 12 });
        }
        .width('100%').layoutWeight(1).align(Alignment.TopStart).scrollBar(BarState.Off);
      }
      .layoutWeight(1)
      .height('100%')
      .constraintSize({ minWidth: AppTheme.PARENT_REVIEW_MIN_WIDTH })
      .padding(AppTheme.CARD_PADDING)
      .backgroundColor(AppTheme.SURFACE_SUBTLE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CARD_RADIUS)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppTheme.PARENT_PROGRESS_REVIEW_MAX_WIDTH })
    .alignItems(VerticalAlign.Top)
    .padding({ left: AppTheme.PAGE_PADDING_WIDE, right: AppTheme.PAGE_PADDING_WIDE, top: 18, bottom: 20 });
  }

  build() {
    Column() {
      if (this.canUseReviewPane()) this.ProgressReviewSplit();
      else this.SingleColumnProgress();
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
