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

  private sourceFrameIds(item: ImportedMessage): string[] {
    return item.sourceEvidence.sourceFrameEvidenceIds === undefined ?
      [] : item.sourceEvidence.sourceFrameEvidenceIds;
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
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`#${item.orderNo}`).fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');

      Text(item.text.length > 0 ? item.text : '（图片消息）')
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.TEXT);

      if (this.sourceFrameIds(item).length > 0) {
        Text(`来源画面：${this.sourceFrameIds(item).length} 个 Frame Evidence`)
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }

      if (item.attachments.length > 0) {
        Text(`附件 ${item.attachments.length} 个`)
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(10);
  }

  @Builder
  private CandidateCard(item: CandidateAssignment) {
    Column({ space: 5 }) {
      Row() {
        Text(item.subject)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
        Blank();
        Text(`${item.expectedMinutes} 分钟`).fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');
      Text(item.title)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Text(item.sourceEvidence.excerpt)
        .width('100%')
        .fontSize(12)
        .lineHeight(17)
        .fontColor(AppTheme.SUBTEXT);
      if (this.sourceMessageIds(item).length > 0) {
        Text(`证据消息：${this.sourceMessageIds(item).join(', ')}`)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(10);
  }

  build() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      DeepPageHeader({
        title: '导入批次详情',
        subtitle: this.batch() === null ? '批次不存在' :
          `${this.statusLabel(this.batch()!.status)} · ${this.batch()!.messageCount} 条消息 · ${this.batch()!.candidateCount} 项作业`,
        backAccessibilityText: '返回作业智能收件箱',
        onBack: () => this.onBack()
      });

      Scroll() {
        Column({ space: 14 }) {
          if (this.batch() === null) {
            Text('找不到这个导入批次')
              .width('100%')
              .fontSize(14)
              .fontColor(AppTheme.SUBTEXT)
              .padding(18)
              .backgroundColor(AppTheme.SURFACE)
              .borderRadius(AppTheme.CONTROL_RADIUS);
          } else {
            Column({ space: 8 }) {
              Text('来源')
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              Text(this.batch()!.sourceLabel)
                .width('100%')
                .fontSize(13)
                .fontColor(AppTheme.SUBTEXT);
              if (this.batch()!.captureSessionId !== undefined &&
                this.batch()!.captureSessionId!.length > 0) {
                Text(`采集会话：${this.batch()!.captureSessionId}`)
                  .width('100%')
                  .fontSize(12)
                  .fontColor(AppTheme.TERTIARY_TEXT);
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.SURFACE)
            .borderRadius(AppTheme.CONTROL_RADIUS);

            if (this.batch()!.sourceProfileId.length > 0) {
              Column({ space: 6 }) {
                Text('班级采集范围')
                  .width('100%')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                if (this.batch()!.sourceProfileName !== undefined &&
                  this.batch()!.sourceProfileName!.length > 0) {
                  Text(`配置：${this.batch()!.sourceProfileName}`)
                    .width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
                }
                if (this.batch()!.expectedGroupTitle !== undefined &&
                  this.batch()!.expectedGroupTitle!.length > 0) {
                  Text(`目标群：${this.batch()!.expectedGroupTitle}`)
                    .width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
                }
                if (this.batch()!.profileStartTime !== undefined &&
                  this.batch()!.profileStartTime!.length > 0) {
                  Text(`时间范围：今天 ${this.batch()!.profileStartTime} 至采集结束`)
                    .width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
                }
                if (this.batch()!.groupValidationStatus !== undefined) {
                  Text(this.batch()!.groupValidationStatus === 'MATCHED' ? '群名校验：匹配' :
                    (this.batch()!.groupValidationStatus === 'MISMATCH' ? '群名校验：不匹配' :
                      (this.batch()!.groupValidationStatus === 'CONFLICT' ? '群名校验：检测到多个微信群，已阻断自动整理' :
                        (this.batch()!.groupConfirmedByUser === true ? '群名校验：未识别，家长已确认继续' :
                          '群名校验：未识别'))))
                    .width('100%')
                    .fontSize(13)
                    .fontColor(this.batch()!.groupValidationStatus === 'MATCHED' ? AppTheme.SUCCESS :
                      ((this.batch()!.groupValidationStatus === 'MISMATCH' ||
                        this.batch()!.groupValidationStatus === 'CONFLICT') ? AppTheme.DANGER : AppTheme.WARNING));
                }
                if (this.batch()!.pipelineStage !== undefined) {
                  Text(`处理阶段：${this.batch()!.pipelineStage}`)
                    .width('100%')
                    .fontSize(12)
                    .fontColor(AppTheme.TERTIARY_TEXT);
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.SURFACE)
              .borderRadius(AppTheme.CONTROL_RADIUS);
            }

            if (this.batch()!.reconstructed === true) {
              Column({ space: 6 }) {
                Text('聊天重建')
                  .width('100%')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                if (this.batch()!.groupTitle !== undefined && this.batch()!.groupTitle!.length > 0) {
                  Text(`群标题：${this.batch()!.groupTitle}`)
                    .width('100%')
                    .fontSize(13)
                    .fontColor(AppTheme.SUBTEXT);
                }
                if (this.batch()!.earliestDetectedTime !== undefined &&
                  this.batch()!.earliestDetectedTime!.length > 0) {
                  Text(`最早识别时间：${this.batch()!.earliestDetectedTime}`)
                    .width('100%')
                    .fontSize(13)
                    .fontColor(AppTheme.SUBTEXT);
                }
                if (this.batch()!.timeBoundaryReached !== undefined) {
                  Text(this.batch()!.timeBoundaryReached === true ? '已达到目标时间边界' : '尚未达到目标时间边界')
                    .width('100%')
                    .fontSize(13)
                    .fontColor(this.batch()!.timeBoundaryReached === true ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
                }
                if (this.batch()!.reconstructionWarnings !== undefined &&
                  this.batch()!.reconstructionWarnings!.length > 0) {
                  Text(`重建提示：${this.batch()!.reconstructionWarnings!.join('、')}`)
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(16)
                    .fontColor(AppTheme.TERTIARY_TEXT);
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.PRIMARY_FAINT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
            }

            if (this.batch()!.understood !== undefined) {
              Column({ space: 6 }) {
                Text('作业理解')
                  .width('100%')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                Text(this.batch()!.understood === true ? '已完成老师识别、分类与任务整理' : '理解未完成，可保留原消息后重试')
                  .width('100%')
                  .fontSize(13)
                  .fontColor(this.batch()!.understood === true ? AppTheme.SUCCESS : AppTheme.WARNING);
                if (this.batch()!.understandingVersion !== undefined &&
                  this.batch()!.understandingVersion!.length > 0) {
                  Text(`规则版本：${this.batch()!.understandingVersion}`)
                    .width('100%')
                    .fontSize(12)
                    .fontColor(AppTheme.TERTIARY_TEXT);
                }
                if (this.batch()!.classificationSummary !== undefined &&
                  this.batch()!.classificationSummary!.length > 0) {
                  Text(this.batch()!.classificationSummary!)
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(16)
                    .fontColor(AppTheme.SUBTEXT);
                }
                if (this.batch()!.pendingReviewMessageIds !== undefined &&
                  this.batch()!.pendingReviewMessageIds!.length > 0) {
                  Text(`待人工确认消息：${this.batch()!.pendingReviewMessageIds!.length} 条`)
                    .width('100%')
                    .fontSize(13)
                    .fontColor(AppTheme.WARNING);
                }
                if (this.batch()!.understandingWarnings !== undefined &&
                  this.batch()!.understandingWarnings!.length > 0) {
                  Text(`理解提示：${this.batch()!.understandingWarnings!.join('、')}`)
                    .width('100%')
                    .fontSize(12)
                    .lineHeight(16)
                    .fontColor(AppTheme.TERTIARY_TEXT);
                }
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.PRIMARY_FAINT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
            }

            Column({ space: 8 }) {
              Text(`${this.batch()!.reconstructed === true ? '重建消息' : '原始消息'} ${this.messages().length}`)
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              ForEach(this.messages(), (item: ImportedMessage) => {
                this.SourceMessageCard(item);
              }, (item: ImportedMessage) => item.id);
            }
            .width('100%');

            Column({ space: 8 }) {
              Text(`候选作业 ${this.candidates().length}`)
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.TEXT);
              ForEach(this.candidates(), (item: CandidateAssignment) => {
                this.CandidateCard(item);
              }, (item: CandidateAssignment) => item.id);
            }
            .width('100%');

            if (this.message.length > 0) {
              Text(this.message)
                .width('100%')
                .fontSize(13)
                .lineHeight(18)
                .fontColor(AppTheme.SUBTEXT)
                .padding(10)
                .backgroundColor(AppTheme.SURFACE_SUBTLE)
                .borderRadius(10);
            }

            if (this.batch()!.status === ImportBatchStatus.RECEIVED &&
              this.batch()!.pendingReviewMessageIds !== undefined &&
              this.batch()!.pendingReviewMessageIds!.length > 0) {
              Button('人工确认未识别消息', { type: ButtonType.Normal })
                .width('100%')
                .height(AppTheme.BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.PRIMARY)
                .fontColor(AppTheme.TEXT_ON_PRIMARY)
                .onClick(() => this.manualReview());
            }

            if (this.batch()!.status === ImportBatchStatus.READY) {
              Button('继续确认并发布', { type: ButtonType.Normal })
                .width('100%')
                .height(AppTheme.BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.PRIMARY)
                .fontColor(AppTheme.TEXT_ON_PRIMARY)
                .onClick(() => this.continueConfirmation());

              if (this.abandonConfirm) {
                Column({ space: 8 }) {
                  Text('放弃这个导入批次？候选作业会从待确认区清除；已经发布的作业不会被删除。')
                    .width('100%')
                    .fontSize(13)
                    .lineHeight(18)
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
