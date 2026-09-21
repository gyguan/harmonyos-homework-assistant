import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { SelectionIds } from '../../../common/state/SelectionIds';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentFilterDialog } from '../../../components/assignment/AssignmentFilterDialog';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { AssignmentMetricKey, AssignmentMetricSummary } from '../../../components/assignment/AssignmentMetricSummary';
import { FilterSummaryEntry } from '../../../components/selection/SelectionControls';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentDateFilter, AssignmentTypeFilter } from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { ParentReviewPane } from '../review/ParentReviewPane';
import { ParentProgressViewModel } from './ParentProgressViewModel';

@Component
export struct ParentProgressPage {
  @Prop revision: number = 0;
  @State private refreshRevision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private selectedAssignmentId: string = '';

  @State private selectedDayEpochMs: number = Date.now();
  @State private subjectCode: string = 'ALL';
  @State private statusFilter: AssignmentMetricKey = AssignmentMetricKey.ALL;
  @State private draftSelectedDayEpochMs: number = Date.now();
  @State private draftSubjectCode: string = 'ALL';
  @State private visibleAssignments: Assignment[] = [];
  @State private snapshotRevision: number = -1;
  @State private querying: boolean = false;
  @State private bulkMode: boolean = false;
  @State private selectedDeleteIds: string[] = [];
  @State private deleteBusy: boolean = false;
  @State private deleteMessage: string = '';
  @State private showDeleteSheet: boolean = false;

  onOpenReview: (assignmentId: string) => void = (_assignmentId: string) => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: ParentProgressViewModel =
    new ParentProgressViewModel(DefaultAssignmentRepository.instance);

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: AssignmentFilterDialog({
      selectedDayEpochMs: $draftSelectedDayEpochMs,
      subjectCode: $draftSubjectCode,
      onQuery: (selectedDayEpochMs: number, subjectCode: string) => {
        void this.applyFilters(selectedDayEpochMs, subjectCode);
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
    if (this.statusFilter === AssignmentMetricKey.PENDING) {
      return [
        AssignmentStatus.NOT_STARTED,
        AssignmentStatus.IN_PROGRESS,
        AssignmentStatus.PAUSED,
        AssignmentStatus.READY_TO_SUBMIT,
        AssignmentStatus.NEEDS_REWORK,
        AssignmentStatus.OVERDUE
      ];
    }
    if (this.statusFilter === AssignmentMetricKey.SUBMITTED) return [AssignmentStatus.SUBMITTED];
    if (this.statusFilter === AssignmentMetricKey.COMPLETED) return [AssignmentStatus.COMPLETED];
    return [];
  }

  private rebuildView(): void {
    let currentRevision = this.revision + this.refreshRevision;
    if (currentRevision < 0) return;
    this.applyItems(this.viewModel.assignmentsOnDay(
      this.subjectCode, this.selectedDayEpochMs, this.statuses()));
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
    return this.viewModel.assignmentsOnDay(
      this.subjectCode, this.selectedDayEpochMs, this.statuses());
  }

  private assignmentRenderKey(item: Assignment): string {
    return `${item.id}|${item.remoteVersion}|${item.status}|${item.title}|${item.dueText}|${item.expectedMinutes}|${item.elapsedSeconds}|${item.reviewNote}`;
  }

  private canDelete(item: Assignment): boolean {
    return item.status !== AssignmentStatus.COMPLETED;
  }

  private isDeleteSelected(assignmentId: string): boolean {
    return SelectionIds.contains(this.selectedDeleteIds, assignmentId);
  }

  private toggleDeleteSelection(item: Assignment): void {
    if (!this.canDelete(item) || this.deleteBusy) return;
    this.selectedDeleteIds = SelectionIds.toggle(this.selectedDeleteIds, item.id);
    this.deleteMessage = '';
  }

  private deletableVisibleAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.currentVisibleAssignments()) {
      if (this.canDelete(item)) result.push(item);
    }
    return result;
  }

  private enterBulkMode(): void {
    this.bulkMode = true;
    this.selectedDeleteIds = [];
    this.deleteMessage = '';
  }

  private exitBulkMode(): void {
    if (this.deleteBusy) return;
    this.bulkMode = false;
    this.selectedDeleteIds = [];
    this.deleteMessage = '';
  }

  private selectAllDeletable(): void {
    let ids: string[] = [];
    for (let item of this.deletableVisibleAssignments()) ids.push(item.id);
    this.selectedDeleteIds = ids;
    this.deleteMessage = '';
  }

  private openDeleteConfirm(): void {
    if (this.selectedDeleteIds.length === 0 || this.deleteBusy) return;
    this.showDeleteSheet = true;
  }

  private async deleteSelectedAssignments(): Promise<void> {
    if (this.deleteBusy || this.selectedDeleteIds.length === 0) return;
    let ids = SelectionIds.copy(this.selectedDeleteIds);
    this.deleteBusy = true;
    this.deleteMessage = '';
    try {
      await this.viewModel.deleteAssignments(ids);
      this.showDeleteSheet = false;
      this.selectedDeleteIds = [];
      this.bulkMode = false;
      this.refreshRevision++;
      this.rebuildView();
      this.onStoreChanged();
    } catch (error) {
      this.showDeleteSheet = false;
      this.deleteMessage = `${error}`;
      this.refreshRevision++;
      this.rebuildView();
      this.onStoreChanged();
    } finally {
      this.deleteBusy = false;
    }
  }

  @Builder
  private DeleteConfirmSheet() {
    Column({ space: 16 }) {
      Text('删除作业')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);
      Text(`确定删除选中的 ${this.selectedDeleteIds.length} 项未完成作业？删除后无法恢复。`)
        .width('100%')
        .fontSize(14)
        .lineHeight(21)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 10 }) {
        Button('取消', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .enabled(!this.deleteBusy)
          .onClick(() => this.showDeleteSheet = false);
        Button(this.deleteBusy ? '正在删除…' : '确认删除', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.DANGER)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .enabled(!this.deleteBusy)
          .onClick(() => { void this.deleteSelectedAssignments(); });
      }
      .width('100%');
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 20, bottom: 28 })
    .backgroundColor(AppTheme.SURFACE);
  }

  @Builder
  private BulkDeleteToolbar() {
    if (this.bulkMode) {
      Row({ space: 10 }) {
        Text(`已选 ${this.selectedDeleteIds.length} 项`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('全选当前')
          .fontSize(13)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 8, right: 8 })
          .onClick(() => this.selectAllDeletable());
        Blank();
        Button(`删除${this.selectedDeleteIds.length > 0 ? ' ' + this.selectedDeleteIds.length : ''}`, { type: ButtonType.Normal })
          .height(38)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(this.selectedDeleteIds.length > 0 && !this.deleteBusy)
          .backgroundColor(this.selectedDeleteIds.length > 0 ? AppTheme.DANGER : AppTheme.DISABLED)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.openDeleteConfirm());
      }
      .width('100%')
      .padding({ left: 10, right: 8, top: 6, bottom: 6 })
      .backgroundColor(AppTheme.SURFACE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  private openFilterDialog(): void {
    if (this.querying) return;
    this.draftSelectedDayEpochMs = this.selectedDayEpochMs;
    this.draftSubjectCode = this.subjectCode;
    this.filterDialogController.open();
  }

  private async applyFilters(selectedDayEpochMs: number, subjectCode: string): Promise<void> {
    if (this.querying) return;
    this.draftSelectedDayEpochMs = selectedDayEpochMs;
    this.draftSubjectCode = subjectCode;
    this.selectedDayEpochMs = selectedDayEpochMs;
    this.subjectCode = subjectCode;
    if (this.bulkMode) this.selectedDeleteIds = [];
    this.filterDialogController.close();
    await this.queryCurrent();
  }

  private async queryCurrent(): Promise<void> {
    if (this.querying) return;
    this.querying = true;
    try {
      let items = await this.viewModel.queryOnDay(
        this.subjectCode, this.selectedDayEpochMs, this.statuses());
      this.applyItems(items);
    } finally {
      this.querying = false;
    }
  }

  private chooseStatus(value: AssignmentMetricKey): void {
    if (this.statusFilter === value || this.querying) return;
    this.statusFilter = value;
    if (this.bulkMode) this.selectedDeleteIds = [];
    void this.queryCurrent();
  }

  private openAssignment(item: Assignment): void {
    if (this.bulkMode) {
      this.toggleDeleteSelection(item);
      return;
    }
    if (this.canUseReviewPane()) this.selectedAssignmentId = item.id;
    else this.onOpenReview(item.id);
  }

  private isSelected(item: Assignment): boolean {
    return this.canUseReviewPane() && this.selectedAssignmentId === item.id;
  }

  private allAssignments(): Assignment[] {
    return this.viewModel.assignments(
      AssignmentTypeFilter.ALL, 'ALL', AssignmentDateFilter.ALL);
  }

  private allCount(): number {
    return this.allAssignments().length;
  }

  private pendingCount(): number {
    let count = 0;
    for (let item of this.allAssignments()) {
      if (item.status !== AssignmentStatus.SUBMITTED && item.status !== AssignmentStatus.COMPLETED) count++;
    }
    return count;
  }

  private submittedCount(): number {
    let count = 0;
    for (let item of this.allAssignments()) if (item.status === AssignmentStatus.SUBMITTED) count++;
    return count;
  }

  private completedCount(): number {
    let count = 0;
    for (let item of this.allAssignments()) if (item.status === AssignmentStatus.COMPLETED) count++;
    return count;
  }

  private isSelectedDayToday(): boolean {
    let now = new Date();
    let today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    let selected = new Date(this.selectedDayEpochMs);
    let selectedStart = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate()).getTime();
    return selectedStart === today;
  }

  private hasActiveFilters(): boolean {
    return !this.isSelectedDayToday() || this.subjectCode !== 'ALL';
  }

  private dateLabel(): string {
    let value = new Date(this.selectedDayEpochMs);
    let month = value.getMonth() + 1;
    let day = value.getDate();
    let monthText = month < 10 ? `0${month}` : `${month}`;
    let dayText = day < 10 ? `0${day}` : `${day}`;
    return `${value.getFullYear()}-${monthText}-${dayText}`;
  }

  private subjectLabel(value: string): string {
    if (value === 'CHINESE') return '语文';
    if (value === 'MATH') return '数学';
    if (value === 'ENGLISH') return '英语';
    if (value === 'OTHER') return '其他';
    return '全部科目';
  }

  private statusLabel(value: AssignmentMetricKey): string {
    if (value === AssignmentMetricKey.PENDING) return '待完成';
    if (value === AssignmentMetricKey.SUBMITTED) return '待验收';
    if (value === AssignmentMetricKey.COMPLETED) return '已完成';
    return '全部任务';
  }

  @Builder
  private FilterBar() {
    Row() {
      FilterSummaryEntry({
        label: '日期', value: this.dateLabel(),
        active: !this.isSelectedDayToday(),
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '科目', value: this.subjectLabel(this.subjectCode),
        active: this.subjectCode !== 'ALL',
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      Text(this.querying ? '查询中…' : '查询')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.hasActiveFilters() ? AppTheme.PRIMARY : AppTheme.TEXT)
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .padding({ left: 18, right: 18 })
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText('打开作业查询')
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
  private StatusSummary() {
    AssignmentMetricSummary({
      allCount: this.allCount(),
      pendingCount: this.pendingCount(),
      submittedCount: this.submittedCount(),
      completedCount: this.completedCount(),
      selectedKey: this.statusFilter,
      interactive: true,
      onSelect: (key: AssignmentMetricKey) => this.chooseStatus(key)
    });
  }

  @Builder
  private ListContent() {
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('作业进度').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        if (this.deletableVisibleAssignments().length > 0 || this.bulkMode) {
          Text(this.bulkMode ? '完成' : '管理')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 10, right: 10 })
            .onClick(() => {
              if (this.bulkMode) this.exitBulkMode();
              else this.enterBulkMode();
            });
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      this.StatusSummary();
      this.FilterBar();
      this.BulkDeleteToolbar();
      if (this.deleteMessage.length > 0) {
        Text(this.deleteMessage).width('100%').fontSize(13).fontColor(AppTheme.DANGER);
      }

      Row() {
        Text(this.querying ? '查询中…' :
          `${this.dateLabel()} · ${this.subjectLabel(this.subjectCode)} · ${this.statusLabel(this.statusFilter)}`)
          .fontSize(13).fontColor(AppTheme.SUBTEXT);
        Blank();
        Text(`${this.currentVisibleAssignments().length} 项`).fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.currentVisibleAssignments().length === 0) {
        Column({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(28).fontColor([AppTheme.TERTIARY_TEXT]);
          Text('当前筛选下没有作业').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('可以调整日期、科目或任务状态。').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%').padding({ top: 30, bottom: 30 });
      } else {
        Column({ space: 7 }) {
          ForEach(this.currentVisibleAssignments(), (item: Assignment) => {
            Row({ space: 8 }) {
              if (this.bulkMode) {
                Text(this.canDelete(item) ? (this.isDeleteSelected(item.id) ? '✓' : '') : '—')
                  .width(28)
                  .height(28)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isDeleteSelected(item.id) ? AppTheme.TEXT_ON_PRIMARY : AppTheme.SUBTEXT)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.isDeleteSelected(item.id) ? AppTheme.PRIMARY : AppTheme.SURFACE_EMPHASIS)
                  .border({ width: 1, color: this.isDeleteSelected(item.id) ? AppTheme.PRIMARY : AppTheme.BORDER })
                  .borderRadius(14)
                  .accessibilityRole(AccessibilityRoleType.BUTTON)
                  .accessibilityText(this.canDelete(item) ?
                    (this.isDeleteSelected(item.id) ? '取消选择这项作业' : '选择这项作业') : '已完成作业不能删除')
                  .onClick(() => this.toggleDeleteSelection(item));
              }
              AssignmentListItem({
                assignment: item,
                selected: this.bulkMode ? this.isDeleteSelected(item.id) : this.isSelected(item),
                showChevron: !this.bulkMode && !this.canUseReviewPane(),
                interactive: !this.bulkMode || this.canDelete(item),
                onOpen: () => this.openAssignment(item)
              })
              .layoutWeight(1);
            }
            .width('100%')
            .alignItems(VerticalAlign.Center);
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
              },
              onDeleted: () => {
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
    .bindSheet($$this.showDeleteSheet, this.DeleteConfirmSheet(), {
      height: '32%',
      showClose: false,
      preferType: SheetType.BOTTOM
    })
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = LayoutPolicy.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
