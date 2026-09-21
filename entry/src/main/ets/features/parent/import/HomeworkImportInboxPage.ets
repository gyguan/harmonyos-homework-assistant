import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import {
  HomeworkImportSourceType,
  ImportBatch,
  ImportBatchStatus
} from '../../../domain/model/ImportModels';
import { HomeworkImportInboxViewModel } from './HomeworkImportInboxViewModel';

@Component
export struct HomeworkImportInboxPage {
  onBack: () => void = () => {};
  onOpenBatch: (batchId: string) => void = (_batchId: string) => {};
  @State private revision: number = 0;
  private readonly viewModel: HomeworkImportInboxViewModel = new HomeworkImportInboxViewModel();

  private batches(): ImportBatch[] {
    let currentRevision = this.revision;
    if (currentRevision < 0) return [];
    return this.viewModel.listBatches();
  }

  private statusLabel(status: ImportBatchStatus): string {
    if (status === ImportBatchStatus.READY) return '待确认';
    if (status === ImportBatchStatus.PUBLISHED) return '已发布';
    if (status === ImportBatchStatus.ABANDONED) return '已放弃';
    if (status === ImportBatchStatus.EMPTY) return '未识别到作业';
    return '已接收';
  }

  private sourceLabel(sourceType: HomeworkImportSourceType): string {
    if (sourceType === HomeworkImportSourceType.SCREENSHOT) return '截图';
    if (sourceType === HomeworkImportSourceType.SHARE) return '系统分享';
    if (sourceType === HomeworkImportSourceType.SCREEN_CAPTURE) return '智能采集';
    return '文字';
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
  private BatchCard(batch: ImportBatch) {
    Row({ space: 12 }) {
      Text(this.sourceLabel(batch.sourceType).substring(0, 1))
        .width(38)
        .height(38)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.PRIMARY)
        .textAlign(TextAlign.Center)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(12);

      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(batch.sourceLabel.length > 0 ? batch.sourceLabel : this.sourceLabel(batch.sourceType))
            .layoutWeight(1)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
          Text(this.statusLabel(batch.status))
            .fontSize(12)
            .fontColor(batch.status === ImportBatchStatus.READY ? AppTheme.WARNING :
              (batch.status === ImportBatchStatus.PUBLISHED ? AppTheme.SUCCESS : AppTheme.SUBTEXT));
        }
        .width('100%');

        Text(`${this.timeText(batch.createdAtEpochMs)} · ${batch.messageCount} 条原始消息 · ${batch.candidateCount} 项候选作业`)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);

      Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .constraintSize({ minHeight: 72 })
    .padding(14)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${batch.sourceLabel}，${this.statusLabel(batch.status)}，查看导入详情`)
    .onClick(() => this.onOpenBatch(batch.id));
  }

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '作业智能收件箱',
        subtitle: '保留每次导入来源、原始消息和候选作业',
        backAccessibilityText: '返回上一页',
        onBack: () => this.onBack()
      });

      Scroll() {
        Column({ space: 12 }) {
          if (this.batches().length === 0) {
            Column({ space: 8 }) {
              Text('还没有导入记录')
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text('从文字或截图整理一次老师作业后，这里会自动留下可追溯的导入批次。')
                .fontSize(13)
                .lineHeight(19)
                .fontColor(AppTheme.SUBTEXT)
                .textAlign(TextAlign.Center);
            }
            .width('100%')
            .padding({ top: 48, bottom: 48 })
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CARD_RADIUS);
          } else {
            ForEach(this.batches(), (batch: ImportBatch) => {
              this.BatchCard(batch);
            }, (batch: ImportBatch) =>
              `${batch.id}:${batch.status}:${batch.messageCount}:${batch.candidateCount}`);
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
        .padding({ top: 4, bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .padding({
      left: AppTheme.PAGE_PADDING,
      right: AppTheme.PAGE_PADDING,
      top: AppTheme.DEEP_PAGE_TOP_PADDING
    })
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
