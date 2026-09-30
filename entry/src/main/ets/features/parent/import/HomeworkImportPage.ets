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
  @State private subjectOptionsOpen: boolean = false;
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
      this.showParseError('请先输入作业内容，或添加作业图片');
      return;
    }

    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkTextImportResult;
      if (this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE && this.sourceImageRef.length > 0) {
        result = await this.viewModel.parseImage(this.sourceImageRef, this.selectedSubject, this.sourceImageLabel, text);
      } else {
        result = await this.viewModel.parseText(text, this.selectedSubject, this.sourceImageRef, this.sourceImageLabel);
      }
      if (studentId !== this.viewModel.activeStudentId()) return;
      if (result.candidateCount > 0) {
        this.parseMessage = `已整理出 ${result.candidateCount} 项作业，请继续核对`;
        this.afterOrganized(result.candidateCount);
      } else {
        this.showParseError('没有整理出作业，请核对内容或点击识别图片文字后重试');
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
    let recognizedText = result.recognizedText.trim();
    if (this.textDraft.indexOf(recognizedText) < 0) {
      this.textDraft = this.textDraft.trim().length > 0 ?
        `${this.textDraft.trim()}\n\n${recognizedText}` : recognizedText;
    }
    this.sourceImageRef = result.imageRef;
    this.sourceImageLabel = sourceLabel;
    this.imageMode = HomeworkImageRecognitionMode.OCR;
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
      let imageRef = await this.viewModel.captureImage();
      if (studentId === this.viewModel.activeStudentId()) this.applySelectedImage(imageRef, '现场拍照');
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
      let imageRef = await this.viewModel.selectImage();
      if (studentId === this.viewModel.activeStudentId()) this.applySelectedImage(imageRef, '相册作业图片');
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
    this.imageMode = HomeworkImageRecognitionMode.AI_IMAGE;
    this.parseMessage = '';
    this.parseError = false;
  }

  private async recognizeImageAsText(): Promise<void> {
    if (this.parseBusy || this.sourceImageRef.length === 0) return;
    let studentId = this.viewModel.activeStudentId();
    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result = await this.viewModel.recognizeSelectedImageText(this.sourceImageRef, this.sourceImageLabel);
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.applyRecognizedImage(result, this.sourceImageLabel);
    } catch (error) {
      if (studentId !== this.viewModel.activeStudentId()) return;
      this.showParseError(error instanceof Error ? error.message : '图片文字识别失败，请重试');
    } finally {
      this.parseBusy = false;
    }
  }

  private useImageAgain(): void {
    if (this.parseBusy) return;
    this.imageMode = HomeworkImageRecognitionMode.AI_IMAGE;
    this.parseMessage = '';
    this.parseError = false;
  }

  private selectSubject(subject: Subject | null): void {
    if (this.parseBusy) return;
    this.selectedSubject = subject;
    this.parseMessage = '';
    this.parseError = false;
  }

  private clearAssignmentText(): void {
    if (this.parseBusy) return;
    this.textDraft = '';
    this.parseMessage = '';
    this.parseError = false;
  }

  private removeSourceImage(): void {
    if (this.parseBusy) return;
    this.sourceImageRef = '';
    this.sourceImageLabel = '';
    this.imageMode = HomeworkImageRecognitionMode.AI_IMAGE;
    this.parseMessage = '';
    this.parseError = false;
  }

  @Builder
  private SubjectSelector() {
    Flex({ wrap: FlexWrap.Wrap }) {
      Row() {
        ChoiceSelectionChip({
          label: '自动识别',
          selected: this.selectedSubject === null,
          onSelect: () => this.selectSubject(null)
        });
      }
      .margin({ right: 8, bottom: 8 });
      Row() {
        ChoiceSelectionChip({
          label: Subject.CHINESE,
          selected: this.selectedSubject === Subject.CHINESE,
          onSelect: () => this.selectSubject(Subject.CHINESE)
        });
      }
      .margin({ right: 8, bottom: 8 });
      Row() {
        ChoiceSelectionChip({
          label: Subject.MATH,
          selected: this.selectedSubject === Subject.MATH,
          onSelect: () => this.selectSubject(Subject.MATH)
        });
      }
      .margin({ right: 8, bottom: 8 });
      Row() {
        ChoiceSelectionChip({
          label: Subject.ENGLISH,
          selected: this.selectedSubject === Subject.ENGLISH,
          onSelect: () => this.selectSubject(Subject.ENGLISH)
        });
      }
      .margin({ right: 8, bottom: 8 });
      Row() {
        ChoiceSelectionChip({
          label: Subject.OTHER,
          selected: this.selectedSubject === Subject.OTHER,
          onSelect: () => this.selectSubject(Subject.OTHER)
        });
      }
      .margin({ right: 8, bottom: 8 });
    }
    .width('100%')
    .enabled(!this.parseBusy);
  }

  @Builder
  private SubjectOptions() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('科目（可选）')
          .layoutWeight(1)
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.selectedSubject === null ? '自动识别' : this.selectedSubject)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(this.selectedSubject === null ? AppTheme.SUBTEXT : AppTheme.PRIMARY);
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(AppTheme.META_SIZE)
          .fontColor([AppTheme.TERTIARY_TEXT])
          .rotate({ angle: this.subjectOptionsOpen ? 90 : 0 });
      }
      .width('100%')
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .enabled(!this.parseBusy)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(`科目：${this.selectedSubject === null ? '自动识别' : this.selectedSubject}，${this.subjectOptionsOpen ? '收起' : '展开'}科目设置`)
      .onClick(() => {
        if (!this.parseBusy) this.subjectOptionsOpen = !this.subjectOptionsOpen;
      });
      if (this.subjectOptionsOpen) {
        this.SubjectSelector();
      }
      Text(this.selectedSubject === null ? '按每项作业自动识别，支持一张图片包含多个科目' :
        '本次所有作业将使用所选科目')
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT);
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
      .enabled(!this.parseBusy)
      .onClick(() => this.onOpenConfirmation());
    }
  }

  @Builder
  private ImportRecordsEntry() {
    Row({ space: 6 }) {
      Text('导入记录')
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(13)
        .fontColor([AppTheme.SUBTEXT]);
    }
    .width('100%')
    .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText('查看历史导入记录')
    .enabled(!this.parseBusy)
    .onClick(() => this.onOpenRecords());
  }

  @Builder
  private RecognitionActions() {
    Row({ space: 8 }) {
      Button('拍照', { type: ButtonType.Normal })
        .layoutWeight(1)
        .constraintSize({ minHeight: AppTheme.SECONDARY_BUTTON_HEIGHT })
        .padding({ top: 10, bottom: 10 })
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .border({ width: 1, color: AppTheme.BORDER })
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontColor(AppTheme.TEXT)
        .accessibilityText('拍照添加作业图片')
        .enabled(!this.parseBusy)
        .onClick(() => { void this.recognizePhoto(); });

      Button('选图片', { type: ButtonType.Normal })
        .layoutWeight(1)
        .constraintSize({ minHeight: AppTheme.SECONDARY_BUTTON_HEIGHT })
        .padding({ top: 10, bottom: 10 })
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .border({ width: 1, color: AppTheme.BORDER })
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontColor(AppTheme.TEXT)
        .accessibilityText('从相册添加作业图片')
        .enabled(!this.parseBusy)
        .onClick(() => { void this.recognizeGallery(); });
    }
    .width('100%');
  }

  private canOrganize(): boolean {
    return !this.parseBusy && (this.textDraft.trim().length > 0 ||
      (this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE && this.sourceImageRef.length > 0));
  }

  @Builder
  private ImageInput() {
    if (this.sourceImageRef.length > 0) {
      Row({ space: 8 }) {
        Text('已添加作业图片')
          .layoutWeight(1)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
        Text('移除图片')
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontColor(AppTheme.PRIMARY)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('移除作业图片，保留文字')
          .enabled(!this.parseBusy)
          .onClick(() => this.removeSourceImage());
      }
      .width('100%');
      Image(this.sourceImageRef)
        .width('100%')
        .height(200)
        .objectFit(ImageFit.Contain)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      Text(this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE ?
        '图片与下方文字将一并交给AI解析' : '已转为文字整理，请核对下方识别结果')
        .width('100%')
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);
      Text(this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE ? '识别图片文字' : '重新用图片解析')
        .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontColor(AppTheme.PRIMARY)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText(this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE ?
          '用系统文字识别读取此图片，之后可编辑文字' : '重新把图片和下方文字交给AI解析')
        .enabled(!this.parseBusy)
        .onClick(() => {
          if (this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE) {
            void this.recognizeImageAsText();
          } else {
            this.useImageAgain();
          }
        });
    }
  }

  @Builder
  private AssignmentInput() {
    Column({ space: 12 }) {
      Text('作业内容')
        .width('100%')
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .lineHeight(AppTheme.SECTION_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      if (this.sourceImageRef.length === 0 && this.textDraft.length === 0) {
        Text('拍照或选择老师通知，也可直接输入文字')
          .width('100%')
          .fontSize(AppTheme.BODY_SIZE)
          .lineHeight(AppTheme.BODY_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      }
      this.RecognitionActions();
      this.ImageInput();
      Row({ space: 8 }) {
        Text(this.sourceImageRef.length > 0 && this.imageMode === HomeworkImageRecognitionMode.AI_IMAGE ?
          '补充文字（可选）' : '作业文字')
          .layoutWeight(1)
          .fontSize(AppTheme.LABEL_TITLE_SIZE)
          .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
        if (this.textDraft.length > 0) {
          Text('清空文字')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontColor(AppTheme.PRIMARY)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('清空作业文字，保留图片')
            .enabled(!this.parseBusy)
            .onClick(() => this.clearAssignmentText());
        }
      }
      .width('100%');
      TextArea({
        placeholder: this.sourceImageRef.length > 0 ? '可补充作业要求，或修改识别出的文字' :
          '例如：语文背诵第12课；数学完成口算练习',
        text: this.textDraft
      })
        .width('100%')
        .height(160)
        .fontSize(AppTheme.FORM_TEXT_SIZE)
        .lineHeight(AppTheme.FORM_TEXT_LINE_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.parseBusy)
        .onChange((value: string) => {
          this.textDraft = value;
          this.parseMessage = '';
          this.parseError = false;
        });
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

      Button(this.parseBusy ? '正在处理…' : '整理并继续', { type: ButtonType.Normal })
        .width('100%')
        .constraintSize({ minHeight: AppTheme.BUTTON_HEIGHT })
        .padding({ top: 12, bottom: 12 })
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(this.canOrganize())
        .fontSize(AppTheme.ACTION_TEXT_SIZE)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.canOrganize() ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => { void this.organize(); });
      Text('下一步核对作业，确认后再发布')
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(AppTheme.CAPTION_SIZE)
        .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);
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
        Column({ space: AppTheme.ITEM_GAP }) {
          this.AssignmentInput();
          this.SubjectOptions();
          this.PendingReview();
          this.ImportRecordsEntry();
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
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
    .justifyContent(FlexAlign.Start)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
