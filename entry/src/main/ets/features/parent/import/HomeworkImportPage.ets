import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkImageImportResult, HomeworkOrganizerMode, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { CandidateAssignment } from '../../../domain/model/HomeworkModels';
import { HomeworkImportViewModel } from './HomeworkImportViewModel';

@Component
export struct HomeworkImportPage {
  @Prop revision: number = 0;
  @Prop embeddedInDeepPage: boolean = false;
  @State private localRevision: number = 0;
  @State private availableWidthVp: number = 390;
  @State private showCandidatesStep: boolean = false;
  @State private textEntryOpen: boolean = false;
  @State private parseBusy: boolean = false;
  @State private parseMessage: string = '';
  @State private parseError: boolean = false;
  @State private textDraft: string = '';
  onOpenConfirmation: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: HomeworkImportViewModel = new HomeworkImportViewModel();

  aboutToAppear(): void {
    this.syncDraft();
    if (this.candidates().length > 0) this.showCandidatesStep = true;
  }

  private touchRevision(): number { return this.revision + this.localRevision; }

  private candidates(): CandidateAssignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.candidates();
  }

  private shouldShowCandidatesStep(): boolean {
    return this.showCandidatesStep && this.candidates().length > 0;
  }

  private canUseSplit(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.importOrganizeRequirement());
  }

  private syncDraft(): void {
    let raw = this.viewModel.rawImport();
    if (this.textDraft.length === 0 && raw.rawText.length > 0) {
      this.textDraft = raw.rawText;
      this.textEntryOpen = true;
    }
  }

  private afterOrganized(candidateCount: number): void {
    this.localRevision++;
    this.onStoreChanged();
    if (candidateCount > 0) this.showCandidatesStep = true;
  }

  private async parseTypedText(): Promise<void> {
    if (this.parseBusy) return;
    let text = this.textDraft.trim();
    if (text.length === 0) {
      this.parseMessage = '请先粘贴或输入老师发来的作业文字';
      this.parseError = true;
      return;
    }
    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkTextImportResult = await this.viewModel.parseText(text);
      if (result.candidateCount > 0) {
        this.afterOrganized(result.candidateCount);
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI ?
          `AI 已整理出 ${result.candidateCount} 项作业，请继续核对` :
          `云端 AI 暂不可用，已用本地规则整理出 ${result.candidateCount} 项作业`;
      } else {
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI ?
          'AI 暂未识别到明确作业，请检查原文后重试' :
          '本地规则暂时没有拆出明确作业，请检查文字中是否包含学科和具体任务';
        this.parseError = true;
      }
    } catch {
      this.parseMessage = '文字整理失败，请稍后重试';
      this.parseError = true;
    } finally {
      this.parseBusy = false;
    }
  }

  private async selectScreenshot(): Promise<void> {
    if (this.parseBusy) return;
    this.parseBusy = true;
    this.parseMessage = '';
    this.parseError = false;
    try {
      let result: HomeworkImageImportResult = await this.viewModel.selectImageAndParse();
      if (!result.selected) {
        this.parseMessage = '已取消选择图片';
        return;
      }
      this.textDraft = result.recognizedText;
      this.textEntryOpen = true;
      this.localRevision++;
      this.onStoreChanged();
      if (result.candidateCount > 0) {
        this.showCandidatesStep = true;
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI ?
          `截图识别完成，AI 已整理出 ${result.candidateCount} 项作业` :
          `截图识别完成；云端 AI 暂不可用，已用本地规则整理出 ${result.candidateCount} 项作业`;
      } else {
        this.parseMessage = '文字识别成功，但还没有整理出明确作业；可以修改文字后重新整理。';
        this.parseError = true;
      }
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
  private ImportAction(symbol: Resource, title: string, description: string, action: () => void) {
    Row({ space: 11 }) {
      SymbolGlyph(symbol).fontSize(22).fontColor([AppTheme.PRIMARY]);
      Column({ space: 3 }) {
        Text(title).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(description).width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›').fontSize(21).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .constraintSize({ minHeight: 58 })
    .padding(13)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${title}，${description}`)
    .onClick(action);
  }

  @Builder
  private TextEditor() {
    Column({ space: 10 }) {
      Row() {
        Text('老师原文').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        Text('收起').fontSize(12).fontColor(AppTheme.PRIMARY)
          .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('收起作业文字输入')
          .onClick(() => this.textEntryOpen = false);
      }
      .width('100%');
      TextArea({
        placeholder: '例如：语文背诵第12课；数学口算20题；英语听读U4，明天检查',
        text: this.textDraft
      })
        .width('100%')
        .height(170)
        .fontSize(15)
        .lineHeight(22)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.textDraft = value);
      Button(this.parseBusy ? '正在整理…' : '让小伴整理', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.parseBusy)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => { void this.parseTypedText(); });
    }
    .width('100%')
    .padding(AppTheme.PHONE_CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private SourcePane() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('老师原文').width('100%')
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
      this.ImportAction($r('sys.symbol.plus_square'), this.parseBusy ? '正在识别截图…' : '选择作业截图并识别',
        '从系统相册选择老师发来的作业截图', () => { void this.selectScreenshot(); });
      this.ImportAction($r('sys.symbol.checkmark_square'), '粘贴或输入作业文字',
        '适合微信群、校讯通等文字通知', () => this.textEntryOpen = true);
      if (this.textEntryOpen) this.TextEditor();
      this.FeedbackBanner();
      if (this.viewModel.rawImport().sourceLabel.length > 0) {
        Text('最近来源 · ' + this.viewModel.rawImport().sourceLabel)
          .width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%');
  }

  @Builder
  private CandidateItem(item: CandidateAssignment) {
    Column({ space: 7 }) {
      Row() {
        Row({ space: 7 }) {
          Text(item.subject).fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
          if (item.confidence < 0.8) {
            Text('低置信').fontSize(10).fontColor(AppTheme.WARNING)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor(AppTheme.WARNING_SOFT).borderRadius(AppTheme.CHIP_RADIUS);
          }
        }
        Blank();
        Text(item.dueText).fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');
      Text(item.title).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT).maxLines(2);
      Text(item.instruction).width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT).maxLines(2);
      Text(`来源证据 · ${item.sourceEvidence.excerpt}`)
        .width('100%').fontSize(11).lineHeight(17)
        .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.TERTIARY_TEXT).maxLines(2);
    }
    .width('100%')
    .padding(12)
    .backgroundColor(item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE)
    .borderRadius(AppTheme.PHONE_CARD_RADIUS);
  }

  @Builder
  private CandidatePane(showBack: boolean) {
    Column({ space: 12 }) {
      if (showBack) {
        Row() {
          Text('‹ 返回老师原文').fontSize(14).fontColor(AppTheme.PRIMARY)
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 4, right: 8 })
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('返回老师原文')
            .onClick(() => this.showCandidatesStep = false);
          Blank();
          Text(`${this.candidates().length} 项`).fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
      }
      Column({ space: 4 }) {
        Text('AI 整理结果').width('100%')
          .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
      if (this.candidates().length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.checkmark_square')).fontSize(30).fontColor([AppTheme.TERTIARY_TEXT]);
          Text('还没有待确认作业').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text('返回老师原文，选择截图或输入文字后再整理。')
            .fontSize(13).lineHeight(20).fontColor(AppTheme.SUBTEXT).textAlign(TextAlign.Center);
        }
        .width('100%')
        .padding({ top: 34, bottom: 34 });
      } else {
        Column({ space: 7 }) {
          ForEach(this.candidates(), (item: CandidateAssignment) => { this.CandidateItem(item); },
            (item: CandidateAssignment) => item.id);
        }
        .width('100%');
        Button(`继续确认 ${this.candidates().length} 项作业`, { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => this.onOpenConfirmation());
      }
    }
    .width('100%');
  }

  @Builder
  private NarrowFlow() {
    Scroll() {
      Column() {
        Column({ space: AppTheme.PHONE_SECTION_GAP }) {
          if (!this.embeddedInDeepPage) {
            Column({ space: 3 }) {
              Text('收作业').fontSize(AppTheme.PHONE_PAGE_TITLE_SIZE)
                .fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);
          }
          if (this.shouldShowCandidatesStep()) this.CandidatePane(true);
          else this.SourcePane();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
        .padding({ left: AppTheme.PHONE_PAGE_PADDING, right: AppTheme.PHONE_PAGE_PADDING,
          top: this.embeddedInDeepPage ? 0 : 14, bottom: 20 });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
  }

  @Builder
  private WideFlow() {
    Column({ space: 14 }) {
      if (!this.embeddedInDeepPage) {
        Column({ space: 3 }) {
          Text('收作业').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);
      }
      Row({ space: AppTheme.SPLIT_PANE_GAP }) {
        Scroll() { this.SourcePane(); }
          .width(AppTheme.IMPORT_SOURCE_MIN_WIDTH)
          .height('100%')
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off);
        Scroll() { this.CandidatePane(false); }
          .layoutWeight(1)
          .height('100%')
          .constraintSize({ minWidth: AppTheme.IMPORT_CANDIDATE_MIN_WIDTH })
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off);
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top);
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppTheme.IMPORT_SPLIT_MAX_WIDTH })
    .padding({ left: AppTheme.PAGE_PADDING_WIDE, right: AppTheme.PAGE_PADDING_WIDE,
      top: this.embeddedInDeepPage ? 0 : 18, bottom: 20 });
  }

  build() {
    Column() {
      if (this.canUseSplit()) this.WideFlow();
      else this.NarrowFlow();
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = LayoutPolicy.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
