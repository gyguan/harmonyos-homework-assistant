import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkImageRecognitionMode, HomeworkImageTextResult, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { Subject } from '../../../domain/model/HomeworkModels';
import { ChoiceSelectionChip } from '../../../components/selection/SelectionControls';
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
  @State private sourceImageLabel: string = '';
  @State private selectedSubject: Subject | null = null;
  @State private imageMode: HomeworkImageRecognitionMode = HomeworkImageRecognitionMode.AI_IMAGE;
  onOpenConfirmation: () => void = () => {};
  onOpenRecords: () => void = () => {};
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
      this.sourceImageLabel = raw.sourceLabel;
    }
  }

  private afterOrganized(candidateCount: number): void {
    this.localRevision++;
    this.onStoreChanged();
    if (candidateCount > 0) this.onOpenConfirmation();
  }

  private async organize(): Promise<void> {
    if (this.parseBusy) return;
    let studentId = this.viewModel.activeStudentId();
    let text = this.textDraft.trim();
    if (text.length === 0 && this.sourceImageRef.length === 0) {
      this.showParseError('请先输入作业内容，或使用拍照/相册识别');
      return;
    }

    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      if (this.imageMode === HomeworkImageRecognitionMode.OCR && this.sourceImageRef.length > 0 && text.length === 0) {
        let extracted = await this.viewModel.recognizeSelectedImageText(this.sourceImageRef, this.sourceImageLabel);
        if (studentId !== this.viewModel.activeStudentId()) return;
        this.applyRecognizedImage(extracted, this.sourceImageLabel);
        return;
      }
      let result: HomeworkTextImportResult;
      if (this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE && this.sourceImageRef.length > 0) {
        result = await this.viewModel.parseImage(this.sourceImageRef, this.selectedSubject, this.sourceImageLabel);
      } else {
        result = await this.viewModel.parseText(text, this.selectedSubject, this.sourceImageRef, this.sourceImageLabel);
      }
      if (studentId !== this.viewModel.activeStudentId()) return;
      if (result.candidateCount > 0) {
        this.parseMessage = `已整理出 ${result.candidateCount} 项作业，请继续核对`;
        this.afterOrganized(result.candidateCount);
      } else {
        this.showParseError('没有整理出作业，请核对内容或切换文字识别后重试');
      }
    } catch (error) {
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.showParseError(error instanceof Error ? error.message : '作业整理失败，请稍后重试');
    } finally {
      this.parseBusy = false;
    }
  }

  private applyRecognizedImage(result: HomeworkImageTextResult, sourceLabel: string): void {
    if (!result.selected) return;
    if (result.recognizedText.trim().length === 0) {
      this.showParseError('没有识别到清晰文字，请换一张图片重试');
      return;
    }
    this.textDraft = result.recognizedText;
    this.sourceImageRef = result.imageRef;
    this.sourceImageLabel = sourceLabel;
    this.parseMessage = '已识别文字，可修改后继续';
    this.parseError = false;
  }

  private async recognizePhoto(): Promise<void> {
    if (this.parseBusy) return;
    let studentId = this.viewModel.activeStudentId();
    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      if (this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE) {
        let imageRef = await this.viewModel.captureImage();
        if (studentId === this.viewModel.activeStudentId()) this.applySelectedImage(imageRef, '现场拍照');
        return;
      }
      let result: HomeworkImageTextResult = await this.viewModel.captureImageText();
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.applyRecognizedImage(result, '现场拍照');
    } catch (error) {
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.showParseError(error instanceof Error ? error.message : '拍照识别失败，请重试');
    } finally {
      this.parseBusy = false;
    }
  }

  private async recognizeGallery(): Promise<void> {
    if (this.parseBusy) return;
    let studentId = this.viewModel.activeStudentId();
    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      if (this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE) {
        let imageRef = await this.viewModel.selectImage();
        if (studentId === this.viewModel.activeStudentId()) this.applySelectedImage(imageRef, '相册作业图片');
        return;
      }
      let result: HomeworkImageTextResult = await this.viewModel.selectImageText();
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.applyRecognizedImage(result, '相册作业图片');
    } catch (error) {
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.showParseError(error instanceof Error ? error.message : '图片识别失败，请重试');
    } finally {
      this.parseBusy = false;
    }
  }

  private showParseError(message: string): void {
    this.parseMessage = message;
    this.parseError = true;
  }

  private applySelectedImage(imageRef: string, sourceLabel: string): void {
    if (imageRef.length === 0) return;
    this.sourceImageRef = imageRef;
    this.sourceImageLabel = sourceLabel;
    this.textDraft = '';
    this.parseMessage = '';
    this.parseError = false;
  }

  private selectImageMode(mode: HomeworkImageRecognitionMode): void {
    if (this.parseBusy || mode === this.imageMode) return;
    this.imageMode = mode;
    if (this.sourceImageRef.length > 0) this.textDraft = '';
    this.parseMessage = '';
    this.parseError = false;
  }

  private selectSubject(subject: Subject | null): void {
    if (this.parseBusy) return;
    this.selectedSubject = subject;
    this.parseMessage = '';
    this.parseError = false;
  }

  private clearAssignmentInput(): void {
    if (this.parseBusy) return;
    this.textDraft = '';
    this.sourceImageRef = '';
    this.sourceImageLabel = '';
    this.parseMessage = '';
    this.parseError = false;
  }

  @Builder
  private SubjectSelector() {
    Column({ space: 7 }) {
      Text('作业科目')
        .width('100%')
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      Row({ space: 8 }) {
        ChoiceSelectionChip({
          label: '自动识别',
          selected: this.selectedSubject === null,
          onSelect: () => this.selectSubject(null)
        });
      }
      .width('100%');
      Row({ space: 8 }) {
        ChoiceSelectionChip({
          label: Subject.CHINESE,
          selected: this.selectedSubject === Subject.CHINESE,
          onSelect: () => this.selectSubject(Subject.CHINESE)
        });
        ChoiceSelectionChip({
          label: Subject.MATH,
          selected: this.selectedSubject === Subject.MATH,
          onSelect: () => this.selectSubject(Subject.MATH)
        });
        ChoiceSelectionChip({
          label: Subject.ENGLISH,
          selected: this.selectedSubject === Subject.ENGLISH,
          onSelect: () => this.selectSubject(Subject.ENGLISH)
        });
        ChoiceSelectionChip({
          label: Subject.OTHER,
          selected: this.selectedSubject === Subject.OTHER,
          onSelect: () => this.selectSubject(Subject.OTHER)
        });
      }
      .width('100%');
      if (this.selectedSubject !== null) {
        Text('本次所有作业将使用所选科目')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%');
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
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(this.parseError ? AppTheme.DANGER : AppTheme.SUCCESS);
      }
      .width('100%')
      .padding(10)
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
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
            .fontColor(AppTheme.TEXT);
          Text('继续上次的核对与发布')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('继续核对')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY);
      }
      .width('100%')
      .constraintSize({ minHeight: 56 })
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(AppTheme.CARD_SURFACE)
      .border({ width: 1, color: AppTheme.BORDER })
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('继续核对待发布作业')
      .onClick(() => this.onOpenConfirmation());
    }
  }

  @Builder
  private ImportRecordsEntry() {
    Row({ space: 6 }) {
      Text('导入记录')
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.PRIMARY);
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([AppTheme.PRIMARY]);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('查看历史导入记录')
    .onClick(() => this.onOpenRecords());
  }

  @Builder
  private RecognitionActions() {
    Row({ space: 8 }) {
      Button(this.parseBusy ? '识别中…' : '拍照识别', { type: ButtonType.Normal })
        .layoutWeight(1)
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .enabled(!this.parseBusy)
        .onClick(() => { void this.recognizePhoto(); });

      Button(this.parseBusy ? '识别中…' : '相册识别', { type: ButtonType.Normal })
        .layoutWeight(1)
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .fontColor(AppTheme.PRIMARY)
        .enabled(!this.parseBusy)
        .onClick(() => { void this.recognizeGallery(); });
    }
    .width('100%');
  }

  @Builder
  private ImageModeSelector() {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        ChoiceSelectionChip({
          label: 'AI图片解析',
          selected: this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE,
          onSelect: () => this.selectImageMode(HomeworkImageRecognitionMode.AI_IMAGE)
        });
        ChoiceSelectionChip({
          label: '文字识别',
          selected: this.imageMode === HomeworkImageRecognitionMode.OCR,
          onSelect: () => this.selectImageMode(HomeworkImageRecognitionMode.OCR)
        });
      }
      .width('100%');
      Text(this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE ?
        '点击整理并继续，将所选图片发送给AI解析；效果不佳可切换文字识别' :
        '使用系统文字识别，可修改识别文字后继续')
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%');
  }

  private needsImageOcr(): boolean {
    return this.imageMode === HomeworkImageRecognitionMode.OCR &&
      this.sourceImageRef.length > 0 && this.textDraft.trim().length === 0;
  }

  private canOrganize(): boolean {
    return !this.parseBusy && (this.textDraft.trim().length > 0 || this.sourceImageRef.length > 0);
  }

  @Builder
  private AssignmentInput() {
    Column({ space: 12 }) {
      this.SubjectSelector();

      Row() {
        Text('作业内容')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.textDraft.length > 0 || this.sourceImageRef.length > 0) {
          Text('清空')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 12, right: 4 })
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('清空作业内容')
            .onClick(() => this.clearAssignmentInput());
        }
      }
      .width('100%');

      if (this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE && this.sourceImageRef.length > 0) {
        Image(this.sourceImageRef)
          .width('100%')
          .height(200)
          .objectFit(ImageFit.Contain)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      } else {
        TextArea({
          placeholder: '例如：背诵第12课并完成课后练习',
          text: this.textDraft
        })
          .width('100%')
          .height(200)
          .fontSize(AppTheme.FORM_TEXT_SIZE)
          .lineHeight(AppTheme.FORM_TEXT_LINE_HEIGHT)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => {
            this.textDraft = value;
            this.parseMessage = '';
            this.parseError = false;
          });
      }

      this.ImageModeSelector();
      this.RecognitionActions();

      if (this.sourceImageRef.length > 0 && this.imageMode === HomeworkImageRecognitionMode.OCR && this.textDraft.length > 0) {
        Text(`已从${this.sourceImageLabel.length > 0 ? this.sourceImageLabel : '图片'}识别，可继续修改文字`)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
  }

  @Builder
  private ActionFooter() {
    Column({ space: 8 }) {
      this.FeedbackBanner();

      Button(this.parseBusy ? '正在处理…' : (this.needsImageOcr() ? '识别文字' : '整理并继续'), { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(this.canOrganize())
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.canOrganize() ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => { void this.organize(); });
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .backgroundColor(AppTheme.BACKGROUND);
  }

  build() {
    Column() {
      if (!this.embeddedInDeepPage) {
        Text('布置作业')
          .width('100%')
          .fontSize(AppTheme.PAGE_NAV_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .margin({ bottom: 12 });
      }

      Scroll() {
        Column({ space: 10 }) {
          this.PendingReview();
          this.ImportRecordsEntry();
          this.AssignmentInput();
        }
        .width('100%')
        .padding({ bottom: 8 });
      }
      .width('100%')
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);

      this.ActionFooter();
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })
    .padding({
      left: this.embeddedInDeepPage ? 0 : AppTheme.PAGE_PADDING_COMPACT,
      right: this.embeddedInDeepPage ? 0 : AppTheme.PAGE_PADDING_COMPACT,
      top: this.embeddedInDeepPage ? 0 : 14
    })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
