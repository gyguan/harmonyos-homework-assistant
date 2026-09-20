import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkImageImportResult, HomeworkOrganizerMode, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { HomeworkImportViewModel } from './HomeworkImportViewModel';

@Component
export struct HomeworkImportPage {
  @Prop revision: number = 0;
  @Prop embeddedInDeepPage: boolean = false;
  @State private localRevision: number = 0;
  @State private availableWidthVp: number = 390;
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
  }

  private touchRevision(): number { return this.revision + this.localRevision; }

  private pendingCandidateCount(): number {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return 0;
    return this.viewModel.candidates().length;
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
    if (candidateCount > 0) this.onOpenConfirmation();
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
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI ?
          `截图识别完成，AI 已整理出 ${result.candidateCount} 项作业` :
          `截图识别完成；云端 AI 暂不可用，已用本地规则整理出 ${result.candidateCount} 项作业`;
        this.afterOrganized(result.candidateCount);
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
      if (this.pendingCandidateCount() > 0) {
        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text(`已有 ${this.pendingCandidateCount()} 项待发布作业`)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('继续编辑后可直接发布')
              .fontSize(11)
              .fontColor(AppTheme.SUBTEXT);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
          Text('继续编辑')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
        }
        .width('100%')
        .constraintSize({ minHeight: 56 })
        .padding({ left: 13, right: 13, top: 10, bottom: 10 })
        .backgroundColor(AppTheme.PRIMARY_FAINT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .accessibilityRole(AccessibilityRoleType.BUTTON)
        .accessibilityText('继续编辑待发布作业')
        .onClick(() => this.onOpenConfirmation());
      }
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
          this.SourcePane();
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
    Scroll() {
      Column() {
        Column({ space: 14 }) {
          if (!this.embeddedInDeepPage) {
            Text('收作业')
              .width('100%')
              .fontSize(AppTheme.PAGE_TITLE_SIZE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppTheme.TEXT);
          }
          this.SourcePane();
        }
        .width('100%')
        .constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })
        .padding({ left: AppTheme.PAGE_PADDING_WIDE, right: AppTheme.PAGE_PADDING_WIDE,
          top: this.embeddedInDeepPage ? 0 : 18, bottom: 20 });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width('100%')
    .height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off);
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
