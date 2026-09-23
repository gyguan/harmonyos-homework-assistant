import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkImageTextResult, HomeworkOrganizerMode, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { HomeworkImportViewModel } from './HomeworkImportViewModel';

@Component
export struct HomeworkImportPage {
  @Prop revision: number = 0;
  @Prop embeddedInDeepPage: boolean = false;
  @State private localRevision: number = 0;
  @State private parseBusy: boolean = false;
  @State private parseMessage: string = '';
  @State private parseError: boolean = false;
  @State private textDraft: string = '';
  @State private sourceImageRef: string = '';
  onOpenConfirmation: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: HomeworkImportViewModel = new HomeworkImportViewModel();

  aboutToAppear(): void {
    this.syncDraft();
  }

  private touchRevision(): number {
    return this.revision + this.localRevision;
  }

  private pendingCandidateCount(): number {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return 0;
    return this.viewModel.candidates().length;
  }

  private syncDraft(): void {
    let raw = this.viewModel.rawImport();
    if (this.textDraft.length === 0 && raw.rawText.length > 0) this.textDraft = raw.rawText;
    if (this.sourceImageRef.length === 0 && raw.resourceUri.length > 0) {
      this.sourceImageRef = raw.resourceUri;
    }
  }

  private afterOrganized(candidateCount: number): void {
    this.localRevision++;
    this.onStoreChanged();
    if (candidateCount > 0) this.onOpenConfirmation();
  }

  private async organize(): Promise<void> {
    if (this.parseBusy) return;
    let text = this.textDraft.trim();
    if (text.length === 0) {
      this.parseMessage = '请先输入作业内容，或从作业截图识别文字';
      this.parseError = true;
      return;
    }

    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkTextImportResult =
        await this.viewModel.parseText(text, this.sourceImageRef);
      if (result.candidateCount > 0) {
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI ?
          `已整理出 ${result.candidateCount} 项作业，请继续核对` :
          `已整理出 ${result.candidateCount} 项作业，请继续核对`;
        this.afterOrganized(result.candidateCount);
      } else {
        this.parseMessage = '暂时无法整理这段内容，请修改后重试';
        this.parseError = true;
      }
    } catch {
      this.parseMessage = '作业整理失败，请稍后重试';
      this.parseError = true;
    } finally {
      this.parseBusy = false;
    }
  }

  private async recognizeScreenshot(): Promise<void> {
    if (this.parseBusy) return;
    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkImageTextResult = await this.viewModel.selectImageText();
      if (!result.selected) return;
      if (result.recognizedText.trim().length === 0) {
        this.parseMessage = '没有识别到清晰文字，请换一张截图重试';
        this.parseError = true;
        return;
      }
      this.textDraft = result.recognizedText;
      this.sourceImageRef = result.imageRef;
      this.parseMessage = '已识别截图文字，可以修改后再整理';
    } catch {
      this.parseMessage = '截图识别失败，请换一张更清晰的图片后重试';
      this.parseError = true;
    } finally {
      this.parseBusy = false;
    }
  }

  @Builder
  private FeedbackBanner() {
    if (this.parseMessage.length > 0) {
      Row({ space: 8 }) {
        SymbolGlyph(this.parseError ? $r('sys.symbol.exclamationmark_circle_fill') :
          $r('sys.symbol.checkmark_circle_fill'))
          .fontSize(17)
          .fontColor([this.parseError ? AppTheme.DANGER : AppTheme.SUCCESS]);
        Text(this.parseMessage)
          .layoutWeight(1)
          .fontSize(13)
          .lineHeight(19)
          .fontColor(this.parseError ? AppTheme.DANGER : AppTheme.SUCCESS);
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.parseError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private PendingReview() {
    if (this.pendingCandidateCount() > 0) {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(`已有 ${this.pendingCandidateCount()} 项待发布作业`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('可以继续上次的核对与发布')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('继续核对')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: 58 })
      .padding({ left: 13, right: 13, top: 10, bottom: 10 })
      .backgroundColor(AppTheme.PRIMARY_FAINT)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('继续核对待发布作业')
      .onClick(() => this.onOpenConfirmation());
    }
  }

  @Builder
  private AssignmentInput() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('作业内容')
          .width('100%')
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('粘贴老师发来的作业，也可以直接写你想布置的任务')
          .width('100%')
          .fontSize(13)
          .lineHeight(19)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      TextArea({
        placeholder: '例如：语文背诵第12课；数学口算20题；晚上跳绳15分钟',
        text: this.textDraft
      })
        .width('100%')
        .height(190)
        .fontSize(15)
        .lineHeight(22)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => {
          this.textDraft = value;
          this.parseMessage = '';
          this.parseError = false;
        });

      Button(this.parseBusy ? '正在识别…' : '从作业截图识别文字', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .enabled(!this.parseBusy)
        .onClick(() => { void this.recognizeScreenshot(); });

      if (this.sourceImageRef.length > 0) {
        Text('当前内容来自作业截图，可继续修改文字')
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }

      Button(this.parseBusy ? '正在整理…' : '整理作业', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.parseBusy && this.textDraft.trim().length > 0)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.textDraft.trim().length > 0 ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => { void this.organize(); });
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  build() {
    Scroll() {
      Column() {
        Column({ space: AppTheme.PHONE_SECTION_GAP }) {
          if (!this.embeddedInDeepPage) {
            Text('布置作业')
              .width('100%')
              .fontSize(AppTheme.PHONE_PAGE_TITLE_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT);
          }

          this.PendingReview();
          this.AssignmentInput();
          this.FeedbackBanner();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
        .padding({
          left: AppTheme.PHONE_PAGE_PADDING,
          right: AppTheme.PHONE_PAGE_PADDING,
          top: this.embeddedInDeepPage ? 0 : 14,
          bottom: 20
        });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
