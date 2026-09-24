import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import {
  ImportBatch,
  ImportBatchStatus,
  ImportedMessage
} from '../../../domain/model/ImportModels';
import { CandidateAssignment } from '../../../domain/model/HomeworkModels';
import { HomeworkImportInboxViewModel } from './HomeworkImportInboxViewModel';

@Component
export struct HomeworkImportBatchDetailPage {
  @Prop batchId: string = '';
  onBack: () => void = () => {};
  onOpenConfirmation: () => void = () => {};
  @State private revision: number = 0;
  @State private message: string = '';
  @State private abandonConfirm: boolean = false;
  private readonly viewModel: HomeworkImportInboxViewModel = new HomeworkImportInboxViewModel();

  private batch(): ImportBatch | null {
    let currentRevision = this.revision;
    if (currentRevision < 0) return null;
    return this.viewModel.batch(this.batchId);
  }

  private messages(): ImportedMessage[] {
    let currentRevision = this.revision;
    if (currentRevision < 0) return [];
    return this.viewModel.messages(this.batchId);
  }

  private candidates(): CandidateAssignment[] {
    let currentRevision = this.revision;
    if (currentRevision < 0) return [];
    return this.viewModel.candidates(this.batchId);
  }

  private sourceMessageIds(item: CandidateAssignment): string[] {
    return item.sourceEvidence.sourceMessageIds === undefined ?
      [] : item.sourceEvidence.sourceMessageIds;
  }

  private statusLabel(status: ImportBatchStatus): string {
    if (status === ImportBatchStatus.READY) return '待确认';
    if (status === ImportBatchStatus.PUBLISHED) return '已发布';
    if (status === ImportBatchStatus.ABANDONED) return '已放弃';
    if (status === ImportBatchStatus.EMPTY) return '未识别到作业';
    return '已接收';
  }

  private manualReview(): void {
    if (!this.viewModel.activateForManualReview(this.batchId)) {
      this.message = '这个批次当前无法进入人工确认';
      return;
    }
    this.message = '';
    this.onOpenConfirmation();
  }

  private continueConfirmation(): void {
    if (!this.viewModel.activate(this.batchId)) {
      this.message = '这个批次当前无法继续确认';
      return;
    }
    this.message = '';
    this.onOpenConfirmation();
  }

  private abandon(): void {
    if (!this.viewModel.abandon(this.batchId)) {
      this.message = '已发布批次不能放弃';
      this.abandonConfirm = false;
      return;
    }
    this.abandonConfirm = false;
    this.revision++;
    this.message = '已放弃这个导入批次；已发布作业不会受影响。';
  }

  @Builder
  private SourceMessageCard(item: ImportedMessage) {
    Column({ space: 6 }) {
      Row() {
        Text(item.sender.length > 0 ? item.sender : '原始内容')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`#${item.orderNo}`).fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');

      Text(item.text.length > 0 ? item.text : '（图片消息）')
        .width('100%')
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(AppTheme.BODY_LINE_HEIGHT)
        .fontColor(AppTheme.TEXT);

      if (item.attachments.length > 0) {
        Text(`附件 ${item.attachments.length} 个`)
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private CandidateCard(item: CandidateAssignment) {
    Column({ space: 5 }) {
      Row() {
        Text(item.subject)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
        Blank();
        Text(`${item.expectedMinutes} 分钟`).fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');
      Text(item.title)
        .width('100%')
        .fontSize(AppTheme.CARD_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text(item.sourceEvidence.excerpt)
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      if (this.sourceMessageIds(item).length > 0) {
        Text(`证据消息：${this.sourceMessageIds(item).join(', ')}`)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  build() {
    Column() {
      Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '导入批次详情',
        subtitle: this.batch() === null ? '批次不存在' :
          `${this.statusLabel(this.batch()!.status)} · ${this.batch()!.messageCount} 条消息 · ${this.batch()!.candidateCount} 项作业`,
        backAccessibilityText: '返回作业收件箱',
        onBack: () => this.onBack()
      });

      Scroll() {
        Column({ space: 14 }) {
          if (this.batch() === null) {
            Text('找不到这个导入批次')
              .width('100%')
              .fontSize(AppTheme.BODY_SIZE)
              .lineHeight(AppTheme.BODY_LINE_HEIGHT)
              .fontColor(AppTheme.SUBTEXT)
              .padding(18)
              .backgroundColor(AppTheme.SURFACE)
              .border({ width: 1, color: AppTheme.BORDER })
              .borderRadius(AppTheme.PHONE_CARD_RADIUS);
          } else {
            Column({ space: 8 }) {
              Text('来源')
                .width('100%')
                .fontSize(AppTheme.SECTION_TITLE_SIZE)
                .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
                .fontWeight(FontWeight.Medium)
                .maxLines(AppTheme.SECTION_TITLE_MAX_LINES)
                .fontColor(AppTheme.TEXT);
              Text(this.batch()!.sourceLabel)
                .width('100%')
                .fontSize(AppTheme.META_SIZE)
                .lineHeight(AppTheme.META_LINE_HEIGHT)
                .fontColor(AppTheme.SUBTEXT);
        }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.SURFACE)
            .border({ width: 1, color: AppTheme.BORDER })
            .borderRadius(AppTheme.PHONE_CARD_RADIUS);

                        Column({ space: 8 }) {
              Text(`原始消息 ${this.messages().length}`)
                .width('100%')
                .fontSize(AppTheme.SECTION_TITLE_SIZE)
                .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
                .fontWeight(FontWeight.Medium)
                .maxLines(AppTheme.SECTION_TITLE_MAX_LINES)
                .fontColor(AppTheme.TEXT);
              ForEach(this.messages(), (item: ImportedMessage) => {
                this.SourceMessageCard(item);
              }, (item: ImportedMessage) => item.id);
            }
            .width('100%');

            Column({ space: 8 }) {
              Text(`候选作业 ${this.candidates().length}`)
                .width('100%')
                .fontSize(AppTheme.SECTION_TITLE_SIZE)
                .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
                .fontWeight(FontWeight.Medium)
                .maxLines(AppTheme.SECTION_TITLE_MAX_LINES)
                .fontColor(AppTheme.TEXT);
              ForEach(this.candidates(), (item: CandidateAssignment) => {
                this.CandidateCard(item);
              }, (item: CandidateAssignment) => item.id);
            }
            .width('100%');

            if (this.batch()!.understood !== undefined ||
              (this.batch()!.pendingReviewMessageIds !== undefined &&
                this.batch()!.pendingReviewMessageIds!.length > 0) ||
              (this.batch()!.understandingWarnings !== undefined &&
                this.batch()!.understandingWarnings!.length > 0)) {
              Column({ space: 6 }) {
                Text('作业理解')
                  .width('100%')
                  .fontSize(AppTheme.SECTION_TITLE_SIZE)
                  .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                Text(this.batch()!.understood === true ? '已完成规则理解' : '规则理解未完成')
                  .width('100%')
                  .fontSize(AppTheme.META_SIZE)
                  .lineHeight(AppTheme.META_LINE_HEIGHT)
                  .fontColor(this.batch()!.understood === true ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
                Text(`待人工确认消息：${this.batch()!.pendingReviewMessageIds === undefined ?
                  0 : this.batch()!.pendingReviewMessageIds!.length}`)
                  .width('100%')
                  .fontSize(AppTheme.META_SIZE)
                  .lineHeight(AppTheme.META_LINE_HEIGHT)
                  .fontColor(AppTheme.SUBTEXT);
                if (this.batch()!.understandingWarnings !== undefined &&
                  this.batch()!.understandingWarnings!.length > 0) {
                  Text(`理解提示：${this.batch()!.understandingWarnings!.join('；')}`)
                    .width('100%')
                    .fontSize(AppTheme.CAPTION_SIZE)
                    .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
                    .fontColor(AppTheme.TERTIARY_TEXT);
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.SURFACE)
              .border({ width: 1, color: AppTheme.BORDER })
              .borderRadius(AppTheme.PHONE_CARD_RADIUS);
            }

            if (this.message.length > 0) {
              Text(this.message)
                .width('100%')
                .fontSize(AppTheme.META_SIZE)
                .lineHeight(AppTheme.META_LINE_HEIGHT)
                .fontColor(AppTheme.SUBTEXT)
                .padding(10)
                .backgroundColor(AppTheme.SURFACE_SUBTLE)
                .borderRadius(AppTheme.CONTROL_RADIUS);
            }

            if (this.batch()!.status === ImportBatchStatus.RECEIVED) {
              Button('人工确认未识别消息', { type: ButtonType.Normal })
                .width('100%')
                .height(AppTheme.BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.PRIMARY)
                .fontColor(AppTheme.TEXT_ON_PRIMARY)
                .onClick(() => this.manualReview());
            } else if (this.batch()!.status === ImportBatchStatus.READY) {
              Button('继续确认并发布', { type: ButtonType.Normal })
                .width('100%')
                .height(AppTheme.BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.PRIMARY)
                .fontColor(AppTheme.TEXT_ON_PRIMARY)
                .onClick(() => this.continueConfirmation());
            }

            if (this.batch()!.status === ImportBatchStatus.RECEIVED ||
              this.batch()!.status === ImportBatchStatus.READY) {
              if (this.abandonConfirm) {
                Column({ space: 8 }) {
                  Text('放弃这个导入批次？候选作业会从待确认区清除；已经发布的作业不会被删除。')
                    .width('100%')
                    .fontSize(AppTheme.BODY_SIZE)
                    .lineHeight(AppTheme.BODY_LINE_HEIGHT)
                    .fontColor(AppTheme.DANGER);
                  Row({ space: 8 }) {
                    Button('取消', { type: ButtonType.Normal })
                      .layoutWeight(1)
                      .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                      .backgroundColor(AppTheme.SURFACE_EMPHASIS)
                      .fontColor(AppTheme.TEXT)
                      .onClick(() => this.abandonConfirm = false);
                    Button('确认放弃', { type: ButtonType.Normal })
                      .layoutWeight(1)
                      .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                      .backgroundColor(AppTheme.DANGER)
                      .fontColor(AppTheme.TEXT_ON_PRIMARY)
                      .onClick(() => this.abandon());
                  }
                  .width('100%');
                }
                .width('100%')
                .padding(12)
                .backgroundColor(AppTheme.DANGER_SOFT)
                .borderRadius(AppTheme.CONTROL_RADIUS);
              } else {
                Button('放弃这个批次', { type: ButtonType.Normal })
                  .width('100%')
                  .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                  .borderRadius(AppTheme.CONTROL_RADIUS)
                  .backgroundColor(AppTheme.SURFACE_EMPHASIS)
                  .fontColor(AppTheme.DANGER)
                  .onClick(() => this.abandonConfirm = true);
              }
            }
          }
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
