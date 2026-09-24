import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { FilterSummaryEntry } from '../../../components/selection/SelectionControls';
import {
  HomeworkImportSourceType,
  ImportBatch,
  ImportBatchStatus
} from '../../../domain/model/ImportModels';
import { HomeworkImportInboxFilterDialog } from './HomeworkImportInboxFilterDialog';
import {
  HomeworkImportInboxFilterLabels,
  HomeworkImportInboxSourceFilter,
  HomeworkImportInboxStatusFilter,
  HomeworkImportInboxTimeFilter
} from './HomeworkImportInboxFilters';
import { HomeworkImportInboxViewModel } from './HomeworkImportInboxViewModel';

@Component
export struct HomeworkImportInboxPage {
  onBack: () => void = () => {};
  onOpenBatch: (batchId: string) => void = (_batchId: string) => {};
  @State private revision: number = 0;
  @State private selectedSource: HomeworkImportInboxSourceFilter = HomeworkImportInboxSourceFilter.ALL;
  @State private selectedStatus: HomeworkImportInboxStatusFilter = HomeworkImportInboxStatusFilter.ALL;
  @State private selectedTime: HomeworkImportInboxTimeFilter = HomeworkImportInboxTimeFilter.ALL;
  @State private draftSource: HomeworkImportInboxSourceFilter = HomeworkImportInboxSourceFilter.ALL;
  @State private draftStatus: HomeworkImportInboxStatusFilter = HomeworkImportInboxStatusFilter.ALL;
  @State private draftTime: HomeworkImportInboxTimeFilter = HomeworkImportInboxTimeFilter.ALL;
  private readonly viewModel: HomeworkImportInboxViewModel = new HomeworkImportInboxViewModel();

  private filterDialogController: CustomDialogController = new CustomDialogController({
    builder: HomeworkImportInboxFilterDialog({
      selectedSource: $draftSource,
      selectedStatus: $draftStatus,
      selectedTime: $draftTime,
      onApply: (
        source: HomeworkImportInboxSourceFilter,
        status: HomeworkImportInboxStatusFilter,
        time: HomeworkImportInboxTimeFilter
      ) => this.applyFilters(source, status, time)
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true
  });

  aboutToAppear(): void {
    this.revision++;
  }

  private allBatches(): ImportBatch[] {
    let currentRevision = this.revision;
    if (currentRevision < 0) return [];
    return this.viewModel.listBatches();
  }

  private batches(): ImportBatch[] {
    return this.viewModel.filterBatches(
      this.allBatches(), this.selectedSource, this.selectedStatus, this.selectedTime);
  }

  private hasActiveFilters(): boolean {
    return this.selectedSource !== HomeworkImportInboxSourceFilter.ALL ||
      this.selectedStatus !== HomeworkImportInboxStatusFilter.ALL ||
      this.selectedTime !== HomeworkImportInboxTimeFilter.ALL;
  }

  private openFilterDialog(): void {
    this.draftSource = this.selectedSource;
    this.draftStatus = this.selectedStatus;
    this.draftTime = this.selectedTime;
    this.filterDialogController.open();
  }

  private applyFilters(
    source: HomeworkImportInboxSourceFilter,
    status: HomeworkImportInboxStatusFilter,
    time: HomeworkImportInboxTimeFilter
  ): void {
    this.selectedSource = source;
    this.selectedStatus = status;
    this.selectedTime = time;
    this.filterDialogController.close();
  }

  private statusLabel(status: ImportBatchStatus): string {
    if (status === ImportBatchStatus.READY) return '待确认';
    if (status === ImportBatchStatus.PUBLISHED) return '已发布';
    if (status === ImportBatchStatus.ABANDONED) return '已放弃';
    if (status === ImportBatchStatus.EMPTY) return '未识别到作业';
    return '已接收';
  }

  private statusColor(status: ImportBatchStatus): string {
    if (status === ImportBatchStatus.READY) return AppTheme.WARNING;
    if (status === ImportBatchStatus.PUBLISHED) return AppTheme.SUCCESS;
    if (status === ImportBatchStatus.ABANDONED) return AppTheme.DANGER;
    if (status === ImportBatchStatus.RECEIVED) return AppTheme.PRIMARY;
    return AppTheme.SUBTEXT;
  }

  private statusBackground(status: ImportBatchStatus): string {
    if (status === ImportBatchStatus.READY) return AppTheme.WARNING_SOFT;
    if (status === ImportBatchStatus.PUBLISHED) return AppTheme.SUCCESS_SOFT;
    if (status === ImportBatchStatus.ABANDONED) return AppTheme.DANGER_SOFT;
    if (status === ImportBatchStatus.RECEIVED) return AppTheme.PRIMARY_SOFT;
    return AppTheme.SURFACE_EMPHASIS;
  }

  private sourceLabel(sourceType: HomeworkImportSourceType): string {
    if (sourceType === HomeworkImportSourceType.SCREENSHOT) return '截图';
    if (sourceType === HomeworkImportSourceType.SHARE) return '系统分享';
    return '文字';
  }

  private sourceBadge(sourceType: HomeworkImportSourceType): string {
    if (sourceType === HomeworkImportSourceType.SCREENSHOT) return '图';
    if (sourceType === HomeworkImportSourceType.SHARE) return '享';
    return '文';
  }

  private batchTitle(batch: ImportBatch): string {
    return batch.sourceLabel.length > 0 ? batch.sourceLabel : this.sourceLabel(batch.sourceType);
  }

  private timeText(epochMs: number): string {
    if (epochMs <= 0) return '时间未知';
    let date = new Date(epochMs);
    return `${this.two(date.getMonth() + 1)}/${this.two(date.getDate())} ` +
      `${this.two(date.getHours())}:${this.two(date.getMinutes())}`;
  }

  private two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  @Builder
  private FilterBar() {
    Row() {
      FilterSummaryEntry({
        label: '来源',
        value: HomeworkImportInboxFilterLabels.source(this.selectedSource),
        active: this.selectedSource !== HomeworkImportInboxSourceFilter.ALL,
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '状态',
        value: HomeworkImportInboxFilterLabels.status(this.selectedStatus),
        active: this.selectedStatus !== HomeworkImportInboxStatusFilter.ALL,
        onOpen: () => this.openFilterDialog()
      });
      Divider().vertical(true).height(28).color(AppTheme.DIVIDER);
      FilterSummaryEntry({
        label: '时间',
        value: HomeworkImportInboxFilterLabels.time(this.selectedTime),
        active: this.selectedTime !== HomeworkImportInboxTimeFilter.ALL,
        onOpen: () => this.openFilterDialog()
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
  private BatchCard(batch: ImportBatch) {
    Row({ space: 12 }) {
      Text(this.sourceBadge(batch.sourceType))
        .width(40)
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(12);

      Column({ space: 6 }) {
        Row({ space: 8 }) {
          Text(this.batchTitle(batch))
            .layoutWeight(1)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(this.statusLabel(batch.status))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor(batch.status))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.statusBackground(batch.status))
            .borderRadius(AppTheme.CHIP_RADIUS);
        }
        .width('100%')
        .alignItems(VerticalAlign.Center);

        Text(`${this.sourceLabel(batch.sourceType)} · ${this.timeText(batch.createdAtEpochMs)}`)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });

        Row({ space: 8 }) {
          Text(`${batch.messageCount} 条消息`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
          Text('·').fontSize(13).fontColor(AppTheme.TERTIARY_TEXT);
          Text(`${batch.candidateCount} 项作业`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([AppTheme.TERTIARY_TEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: 92 })
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${this.batchTitle(batch)}，${this.sourceLabel(batch.sourceType)}，${this.statusLabel(batch.status)}`)
    .onClick(() => this.onOpenBatch(batch.id));
  }

  @Builder
  private InboxContent() {
    Column({ space: 12 }) {
      this.FilterBar();

      Row() {
        Text(this.hasActiveFilters() ? '筛选结果' : '全部记录')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.batches().length} 条`)
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.allBatches().length === 0) {
        Column({ space: 8 }) {
          Text('箱')
            .width(36)
            .height(36)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.PRIMARY)
            .textAlign(TextAlign.Center)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .borderRadius(11);
          Text('还没有导入记录')
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
        }
        .width('100%')
        .padding({ top: 44, bottom: 44 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.PHONE_CARD_RADIUS);
      } else if (this.batches().length === 0) {
        Column({ space: 8 }) {
          Text('没有符合条件的记录')
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
        }
        .width('100%')
        .padding({ top: 36, bottom: 36 })
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.PHONE_CARD_RADIUS);
      } else {
        Column({ space: 9 }) {
          ForEach(this.batches(), (batch: ImportBatch) => {
            this.BatchCard(batch);
          }, (batch: ImportBatch) =>
            `${batch.id}:${batch.status}:${batch.messageCount}:${batch.candidateCount}`);
        }
        .width('100%');
      }
    }
    .width('100%');
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
        DeepPageHeader({
          title: '作业收件箱',
          backAccessibilityText: '返回上一页',
          onBack: () => this.onBack()
        });

        Scroll() {
          Column() {
            this.InboxContent();
          }
          .width('100%')
          .padding({ top: 4, bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .layoutWeight(1)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off);
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
      .padding({
        left: AppTheme.PAGE_PADDING,
        right: AppTheme.PAGE_PADDING,
        top: AppTheme.DEEP_PAGE_TOP_PADDING
      });
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
