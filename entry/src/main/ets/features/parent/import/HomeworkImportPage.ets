import { AppTheme } from '../../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind } from '../../../components/action/ActionControls';
import { HomeworkImageTextResult, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
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
  @State private selectedSubject: Subject = Subject.CHINESE;
  @State private subjectChosen: boolean = false;
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
    if (!this.subjectChosen) {
      this.showParseError('请先选择作业科目');
      return;
    }
    let text = this.textDraft.trim();
    if (text.length === 0) {
      this.showParseError('请先输入作业内容，或使用拍照/相册识别');
      return;
    }

    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkTextImportResult =
        await this.viewModel.parseText(text, this.selectedSubject, this.sourceImageRef, this.sourceImageLabel);
      if (result.candidateCount > 0) {
        this.parseMessage = `已整理出 ${result.candidateCount} 项作业，请继续核对`;
        this.afterOrganized(result.candidateCount);
      } else {
        this.showParseError('暂时无法整理这段内容，请修改后重试');
      }
    } catch {
      this.showParseError('作业整理失败，请稍后重试');
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
    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkImageTextResult = await this.viewModel.captureImageText();
      this.applyRecognizedImage(result, '现场拍照');
    } catch {
      this.showParseError('拍照识别失败，请重新拍摄更清晰的作业内容');
    } finally {
      this.parseBusy = false;
    }
  }

  private async recognizeGallery(): Promise<void> {
    if (this.parseBusy) return;
    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkImageTextResult = await this.viewModel.selectImageText();
      this.applyRecognizedImage(result, '相册作业图片');
    } catch {
      this.showParseError('图片识别失败，请选择更清晰的作业图片');
    } finally {
      this.parseBusy = false;
    }
  }

  private showParseError(message: string): void {
    this.parseMessage = message;
    this.parseError = true;
  }

  private selectSubject(subject: Subject): void {
    if (this.parseBusy) return;
    this.selectedSubject = subject;
    this.subjectChosen = true;
    this.parseMessage = '';
    this.parseError = false;
  }

  @Builder
  private SubjectSelector() {
    Column({ space: 7 }) {
      Text('作业科目')
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        ChoiceSelectionChip({
          label: Subject.CHINESE,
          selected: this.subjectChosen && this.selectedSubject === Subject.CHINESE,
          onSelect: () => this.selectSubject(Subject.CHINESE)
        });
        ChoiceSelectionChip({
          label: Subject.MATH,
          selected: this.subjectChosen && this.selectedSubject === Subject.MATH,
          onSelect: () => this.selectSubject(Subject.MATH)
        });
        ChoiceSelectionChip({
          label: Subject.ENGLISH,
          selected: this.subjectChosen && this.selectedSubject === Subject.ENGLISH,
          onSelect: () => this.selectSubject(Subject.ENGLISH)
        });
        ChoiceSelectionChip({
          label: Subject.OTHER,
          selected: this.subjectChosen && this.selectedSubject === Subject.OTHER,
          onSelect: () => this.selectSubject(Subject.OTHER)
        });
      }
      .width('100%');
      if (!this.subjectChosen) {
        Text('请先选择本次作业的科目，整理后不会自动修改')
          .width('100%')
          .fontSize(11)
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
          .fontSize(13)
          .lineHeight(19)
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
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('继续上次的核对与发布')
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
      .constraintSize({ minHeight: 56 })
      .padding({ left: 12, right: 12, top: 9, bottom: 9 })
      .backgroundColor(AppTheme.PRIMARY_FAINT)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText('继续核对待发布作业')
      .onClick(() => this.onOpenConfirmation());
    }
  }

  @Builder
  private RecognitionActions() {
    Row({ space: 8 }) {
      ActionButton({
        label: this.parseBusy ? '识别中…' : '拍照识别',
        kind: ActionButtonKind.SECONDARY,
        compact: true,
        isEnabled: !this.parseBusy,
        onAction: (): void => { void this.recognizePhoto(); }
      })
      .layoutWeight(1);

      ActionButton({
        label: this.parseBusy ? '识别中…' : '相册识别',
        kind: ActionButtonKind.SECONDARY,
        compact: true,
        isEnabled: !this.parseBusy,
        onAction: (): void => { void this.recognizeGallery(); }
      })
      .layoutWeight(1);
    }
    .width('100%');
  }

  @Builder
  private AssignmentInput() {
    Column({ space: 12 }) {
      this.SubjectSelector();

      Row() {
        Text('作业内容')
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text('输入 · 拍照 · 相册')
          .fontSize(11)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');

      TextArea({
        placeholder: '例如：背诵第12课并完成课后练习',
        text: this.textDraft
      })
        .width('100%')
        .height(200)
        .fontSize(15)
        .lineHeight(22)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => {
          this.textDraft = value;
          this.parseMessage = '';
          this.parseError = false;
        });

      this.RecognitionActions();

      if (this.sourceImageRef.length > 0) {
        Text(`已从${this.sourceImageLabel.length > 0 ? this.sourceImageLabel : '图片'}识别，可继续修改文字`)
          .width('100%')
          .fontSize(11)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private ActionFooter() {
    Column({ space: 8 }) {
      this.FeedbackBanner();

      ActionButton({
        label: this.parseBusy ? '正在处理…' : '整理并继续',
        isEnabled: !this.parseBusy && this.subjectChosen && this.textDraft.trim().length > 0,
        onAction: (): void => { void this.organize(); }
      })
      .width('100%');
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
          .fontSize(AppTheme.PHONE_PAGE_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT)
          .margin({ bottom: 12 });
      }

      Scroll() {
        Column({ space: 10 }) {
          this.PendingReview();
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
    .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
    .padding({
      left: AppTheme.PHONE_PAGE_PADDING,
      right: AppTheme.PHONE_PAGE_PADDING,
      top: this.embeddedInDeepPage ? 0 : 14
    })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
