import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkShareImportService } from '../../../application/import/HomeworkShareImportService';

enum ShareImportPhase {
  PROCESSING = 'PROCESSING',
  FAILED = 'FAILED',
  EMPTY = 'EMPTY'
}

@Component
export struct HomeworkShareImportStatusPage {
  @Prop token: string = '';
  onReady: () => void = () => {};
  onOpenInbox: () => void = () => {};
  onCancel: () => void = () => {};
  @State private phase: ShareImportPhase = ShareImportPhase.PROCESSING;
  @State private message: string = '正在整理分享的老师作业…';
  private processingStarted: boolean = false;

  aboutToAppear(): void {
    this.startProcessing();
  }

  private startProcessing(): void {
    if (this.processingStarted || this.token.length === 0) return;
    this.processingStarted = true;
    this.phase = ShareImportPhase.PROCESSING;
    this.message = '正在整理分享的老师作业…';
    void this.process();
  }

  private async process(): Promise<void> {
    try {
      let result = await HomeworkShareImportService.instance.process(this.token);
      if (result.candidateCount > 0) {
        this.onReady();
        return;
      }
      this.phase = ShareImportPhase.EMPTY;
      this.message = '没有识别到可发布作业，本次分享已记录到作业智能收件箱。';
    } catch (error) {
      this.phase = ShareImportPhase.FAILED;
      let detail = `${error}`;
      this.message = detail.indexOf('图片') >= 0 || detail.indexOf('识别') >= 0 ?
        '无法读取或识别分享图片，请重试。' : '系统分享整理失败，请重试。';
    }
  }

  private retry(): void {
    if (this.phase !== ShareImportPhase.FAILED) return;
    this.processingStarted = false;
    this.startProcessing();
  }

  private async cancel(): Promise<void> {
    try {
      await HomeworkShareImportService.instance.cancel(this.token);
    } finally {
      this.onCancel();
    }
  }

  build() {
    Column({ space: 18 }) {
      Text('系统分享导入')
        .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      Text(this.phase === ShareImportPhase.PROCESSING ? '整理中' :
        (this.phase === ShareImportPhase.FAILED ? '需要处理' : '整理完成'))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.phase === ShareImportPhase.FAILED ? AppTheme.DANGER :
          (this.phase === ShareImportPhase.EMPTY ? AppTheme.SUCCESS : AppTheme.PRIMARY))
        .padding({ left: 12, right: 12, top: 5, bottom: 5 })
        .backgroundColor(this.phase === ShareImportPhase.FAILED ? AppTheme.DANGER_SOFT :
          (this.phase === ShareImportPhase.EMPTY ? AppTheme.SUCCESS_SOFT : AppTheme.PRIMARY_SOFT))
        .borderRadius(AppTheme.CHIP_RADIUS);

      Text(this.message)
        .width('100%')
        .fontSize(14)
        .lineHeight(21)
        .fontColor(AppTheme.SUBTEXT)
        .textAlign(TextAlign.Center);

      if (this.phase === ShareImportPhase.FAILED) {
        Button('重试', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.retry());
      }

      if (this.phase === ShareImportPhase.EMPTY) {
        Button('查看作业智能收件箱', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.onOpenInbox());
      }

      if (this.phase === ShareImportPhase.FAILED) {
        Button('取消导入', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .onClick(() => { void this.cancel(); });
      } else if (this.phase === ShareImportPhase.EMPTY) {
        Button('完成', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .onClick(() => this.onCancel());
      }

    }
    .width('100%')
    .constraintSize({ maxWidth: 460 })
    .padding(24)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }
}
