import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { SelectionIds } from '../../../common/state/SelectionIds';
import { AppTheme } from '../../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind, TextAction, TextActionKind } from '../../../components/action/ActionControls';
import { AssignmentFilterDialog } from '../../../components/assignment/AssignmentFilterDialog';
import { AssignmentListItem } from '../../../components/assignment/AssignmentListItem';
import { FilterSummaryEntry } from '../../../components/selection/SelectionControls';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentDateFilter, AssignmentTypeFilter } from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { ParentReviewPane } from '../review/ParentReviewPane';
import { ParentProgressViewModel } from './ParentProgressViewModel';

@Component
export struct ParentProgressPage {
  @Prop @Watch('onRevisionChanged') revision: number = 0;
  @State private refreshRevision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private selectedAssignmentId: string = '';

  @State private allDates: boolean = false;
  @State private selectedDayEpochMs: number = Date.now();
  @State private subjectCode: string = 'ALL';
  @State private draftAllDates: boolean = false;
  @State private draftSelectedDayEpochMs: number = Date.now();
  @State private draftSubjectCode: string = 'ALL';
  @State private scopedAssignments: Assignment[] = [];
  @State private visibleAssignments: Assignment[] = [];
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

  private onRevisionChanged(): void {
    this.rebuildView();
  }

  private canUseReviewPane(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.parentProgressReviewRequirement());
  }

  private rebuildView(): void {
    let currentRevision = this.revision + this.refreshRevision;
    if (currentRevision < 0) return;
    let scoped = this.allDates ?
      this.viewModel.assignments(
        AssignmentTypeFilter.ALL, this.subjectCode, AssignmentDateFilter.ALL) :
      this.viewModel.assignmentsOnDay(this.subjectCode, this.selectedDayEpochMs);
    this.applyScopedItems(scoped);
  }

  private applyScopedItems(items: Assignment[]): void {
    this.scopedAssignments = items.slice();
    this.applyItems(this.scopedAssignments);
  }

  private applyItems(items: Assignment[]): void {
    this.visibleAssignments = items.slice();
     let stillVisible = false;
    for (let item of items) if (item.id === this.selectedAssignmentId) stillVisible = true;
    if (!stillVisible) this.selectedAssignmentId = items.length > 0 ? items[0].id : '';
  }

  private currentVisibleAssignments(): Assignment[] {
    return this.visibleAssignments;
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
        ActionButton({
          label: '取消',
          kind: ActionButtonKind.NEUTRAL,
          isEnabled: !this.deleteBusy,
          onAction: (): void => { this.showDeleteSheet = false; }
        })
        .layoutWeight(1);
        ActionButton({
          label: this.deleteBusy ? '正在删除…' : '确认删除',
          kind: ActionButtonKind.DANGER,
          isEnabled: !this.deleteBusy,
          onAction: (): void => { void this.deleteSelectedAssignments(); }
        })
        .layoutWeight(1);
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
        TextAction({
          label: '全选当前',
          onAction: (): void => this.selectAllDeletable()
        });
        Blank();
        ActionButton({
          label: `删除${this.selectedDeleteIds.length > 0 ? ' ' + this.selectedDeleteIds.length : ''}`,
          kind: ActionButtonKind.DANGER,
          compact: true,
          isEnabled: this.selectedDeleteIds.length > 0 && !this.deleteBusy,
          onAction: (): void => this.openDeleteConfirm()
        });
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
    this.draftAllDates = this.allDates;
    this.draftSelectedDayEpochMs = this.selectedDayEpochMs;
    this.draftSubjectCode = this.subjectCode;
    this.filterDialogController.open();
  }

  private async applyFilters(allDates: boolean, selectedDayEpochMs: number, subjectCode: string): Promise<void> {
    if (this.querying) return;
    this.draftAllDates = allDates;
    this.draftSelectedDayEpochMs = selectedDayEpochMs;
    this.draftSubjectCode = subjectCode;
    this.allDates = allDates;
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
      let scoped = this.allDates ?
        await this.viewModel.query(
          AssignmentTypeFilter.ALL, this.subjectCode, AssignmentDateFilter.ALL) :
        await this.viewModel.queryOnDay(
          this.subjectCode, this.selectedDayEpochMs);
      this.applyScopedItems(scoped);
    } finally {
      this.querying = false;
    }
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

  private isSelectedDayToday(): boolean {
    let now = new Date();
    let today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    let selected = new Date(this.selectedDayEpochMs);
    let selectedStart = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate()).getTime();
    return selectedStart === today;
  }

  private hasActiveFilters(): boolean {
    return (!this.allDates && !this.isSelectedDayToday()) || this.subjectCode !== 'ALL';
  }

  private dateLabel(): string {
    if (this.allDates) return '全部日期';
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

  @Builder
  private FilterBar() {
    Row() {
      FilterSummaryEntry({
        label: '日期', value: this.dateLabel(),
        active: !this.allDates && !this.isSelectedDayToday(),
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '科目', value: this.subjectLabel(this.subjectCode),
        active: this.subjectCode !== 'ALL',
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      TextAction({
        label: this.querying ? '查询中…' : '查询',
        kind: this.hasActiveFilters() ? TextActionKind.PRIMARY : TextActionKind.NEUTRAL,
        isEnabled: !this.querying,
        accessibilityLabel: '打开作业查询',
        onAction: (): void => this.openFilterDialog()
      });
    }
    .width('100%')
    .height(58)
    .padding({ left: 8, right: 8 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private ListContent() {
    Column({ space: 16 }) {
      this.FilterBar();
      this.BulkDeleteToolbar();
      if (this.deleteMessage.length > 0) {
        Text(this.deleteMessage).width('100%').fontSize(13).fontColor(AppTheme.DANGER);
      }

      Row({ space: 8 }) {
        Text(this.querying ? '查询中…' :
          `${this.dateLabel()} · ${this.subjectLabel(this.subjectCode)}`)
          .layoutWeight(1)
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
        Text(`${this.currentVisibleAssignments().length} 项`)
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
        if (this.deletableVisibleAssignments().length > 0 || this.bulkMode) {
          TextAction({
            label: this.bulkMode ? '取消' : '删除',
            kind: this.bulkMode ? TextActionKind.PRIMARY : TextActionKind.DANGER,
            accessibilityLabel: this.bulkMode ? '取消删除选择' : '选择要删除的作业',
            onAction: (): void => {
              if (this.bulkMode) this.exitBulkMode();
              else this.enterBulkMode();
            }
          });
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      if (this.currentVisibleAssignments().length === 0) {
        Column({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(28).fontColor([AppTheme.TERTIARY_TEXT]);
          Text('当前筛选下没有作业').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('可以调整日期或科目。').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%').padding({ top: 30, bottom: 30 });
      } else {
        Column({ space: 7 }) {
          ForEach(this.currentVisibleAssignments(), (item: Assignment) => {
            AssignmentListItem({
              assignment: item,
              selected: this.bulkMode ? this.isDeleteSelected(item.id) : this.isSelected(item),
              showChevron: !this.bulkMode && !this.canUseReviewPane(),
              interactive: !this.bulkMode || this.canDelete(item),
              selectionMode: this.bulkMode,
              selectionAvailable: this.canDelete(item),
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
