import { HomeworkImportService } from '../../../application/import/HomeworkImportService';
import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { HomeworkImageImportResult, HomeworkOrganizerMode, HomeworkTextImportResult } from '../../../domain/model/ImportModels';
import { CandidateAssignment, RawHomeworkImport } from '../../../domain/model/HomeworkModels';

@Component
export struct HomeworkImportPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private showCompactCandidates: boolean = false;
  @State private textEntryOpen: boolean = false;
  @State private parseBusy: boolean = false;
  @State private parseMessage: string = '';
  @State private parseError: boolean = false;
  @State private textDraft: string = '';
  onOpenConfirmation: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private rawImport(): RawHomeworkImport {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getRawImport();
  }

  private candidates(): CandidateAssignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getCandidates();
  }

  private syncDraftFromStore(): void {
    if (this.textDraft.length === 0 && this.rawImport().rawText.length > 0) {
      this.textDraft = this.rawImport().rawText;
      this.textEntryOpen = true;
    }
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
      let result: HomeworkTextImportResult = await HomeworkImportService.instance.parseText(text);
      if (result.candidateCount > 0) {
        this.onStoreChanged();
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI
          ? `AI 已整理出 ${result.candidateCount} 项作业，请确认后发布`
          : `云端 AI 暂不可用，已用本地规则整理出 ${result.candidateCount} 项作业`;
        if (this.sizeClass === WindowSizeClass.COMPACT) this.showCompactCandidates = true;
      } else {
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI
          ? 'AI 暂未识别到明确作业，请检查原文后重试'
          : '本地规则暂时没有拆出明确作业，请检查文字中是否包含学科和具体任务';
        this.parseError = true;
      }
    } catch (_error) {
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
      let result: HomeworkImageImportResult = await HomeworkImportService.instance.selectImageAndParse();
      if (!result.selected) {
        this.parseMessage = '已取消选择图片';
        return;
      }
      this.textDraft = result.recognizedText;
      this.textEntryOpen = true;
      this.onStoreChanged();
      if (result.candidateCount > 0) {
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI
          ? `截图识别完成，AI 已整理出 ${result.candidateCount} 项作业`
          : `截图识别完成；云端 AI 暂不可用，已用本地规则整理出 ${result.candidateCount} 项作业`;
        if (this.sizeClass === WindowSizeClass.COMPACT) this.showCompactCandidates = true;
      } else {
        this.parseMessage = result.organizerMode === HomeworkOrganizerMode.AI
          ? '文字识别成功，但 AI 暂未识别到明确作业。你可以修改文字后重新整理。'
          : '文字识别成功，但本地规则暂时没有拆出明确作业。你可以修改文字后重新整理。';
        this.parseError = true;
      }
    } catch (_error) {
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
        SymbolGlyph(this.parseError ? $r('sys.symbol.exclamationmark_circle_fill') : $r('sys.symbol.checkmark_circle_fill'))
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
    Row({ space: 14 }) {
      SymbolGlyph(symbol)
        .fontSize(24)
        .fontColor([AppTheme.PRIMARY]);
      Column({ space: 3 }) {
        Text(title)
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(description)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding(15)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${title}，${description}`)
    .onClick(action);
  }

  @Builder
  private TextEditor() {
    Column({ space: 10 }) {
      Row() {
        Text('作业文字')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.sizeClass === WindowSizeClass.COMPACT) {
          Text('收起')
            .fontSize(12)
            .fontColor(AppTheme.PRIMARY)
            .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
            .textAlign(TextAlign.Center)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('收起作业文字输入')
            .onClick(() => this.textEntryOpen = false);
        }
      }
      .width('100%');

      TextArea({
        placeholder: '例如：语文背诵第12课；数学口算20题；英语听读U4，明天检查',
        text: this.textDraft
      })
        .width('100%')
        .height(this.sizeClass === WindowSizeClass.COMPACT ? 168 : 220)
        .fontSize(15)
        .lineHeight(22)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.textDraft = value);

      Button(this.parseBusy ? '正在整理…' : '智能整理作业', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.parseBusy)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(AppTheme.PRIMARY)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => this.parseTypedText());
    }
    .width('100%')
    .padding(15)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private SourcePane() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('把老师发来的内容交给小伴')
          .width('100%')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('优先选择截图，也可以粘贴群里的作业文字。AI 整理后由家长确认。')
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      this.ImportAction(
        $r('sys.symbol.plus_square'),
        this.parseBusy ? '正在识别截图…' : '选择作业截图并识别',
        '从系统相册选择老师发来的作业截图',
        () => { void this.selectScreenshot(); }
      );

      this.ImportAction(
        $r('sys.symbol.checkmark_square'),
        '粘贴或输入作业文字',
        '适合微信群、校讯通等文字通知',
        () => this.textEntryOpen = true
      );

      if (this.textEntryOpen || this.sizeClass !== WindowSizeClass.COMPACT) {
        this.TextEditor();
      }

      this.FeedbackBanner();

      if (this.rawImport().sourceLabel.length > 0) {
        Text('最近来源 · ' + this.rawImport().sourceLabel)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
    }
    .width('100%');
  }

  @Builder
  private CandidateItem(item: CandidateAssignment) {
    Row({ space: 12 }) {
      Text(item.subject.length > 0 ? item.subject.substring(0, 1) : '作')
        .width(36)
        .height(36)
        .padding({ top: 8 })
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.PRIMARY)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .borderRadius(11);
      Column({ space: 4 }) {
        Row() {
          Text(item.title)
            .layoutWeight(1)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT)
            .maxLines(2);
          Text(item.dueText)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
        Text(item.confidence < 0.8 ? '识别置信度较低，请重点确认' : item.sourceEvidence.excerpt)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUBTEXT)
          .maxLines(2);
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding(12)
    .backgroundColor(item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private CandidatePane() {
    Column({ space: 12 }) {
      if (this.sizeClass === WindowSizeClass.COMPACT) {
        Row() {
          Text('‹ 重新导入')
            .fontSize(14)
            .fontColor(AppTheme.PRIMARY)
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 4, right: 8 })
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('返回重新导入')
            .onClick(() => this.showCompactCandidates = false);
          Blank();
          Text(`${this.candidates().length} 项`)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
      }

      Column({ space: 4 }) {
        Text('AI 整理结果')
          .width('100%')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(this.candidates().length > 0 ? '发布前再逐项确认，避免识别错误。' : '整理后，待确认作业会显示在这里。')
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      if (this.candidates().length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.checkmark_square'))
            .fontSize(30)
            .fontColor([AppTheme.TERTIARY_TEXT]);
          Text('还没有待确认作业')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('选择截图或输入老师的作业文字后，小伴会在这里整理结果。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(AppTheme.SUBTEXT)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .padding({ top: 34, bottom: 34 });
      } else {
        Column({ space: 7 }) {
          ForEach(this.candidates(), (item: CandidateAssignment) => {
            this.CandidateItem(item);
          }, (item: CandidateAssignment) => item.id);
        }
        .width('100%');

        Button(`确认 ${this.candidates().length} 项作业`, { type: ButtonType.Normal })
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

  build() {
    Column({ space: 14 }) {
      Column({ space: 4 }) {
        Text('收作业')
          .fontSize(AppTheme.PAGE_TITLE_SIZE)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.TEXT);
        Text('导入老师内容 → 小伴整理 → 家长确认')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      if (this.sizeClass === WindowSizeClass.COMPACT) {
        Scroll() {
          if (this.showCompactCandidates) {
            this.CandidatePane();
          } else {
            this.SourcePane();
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);
      } else {
        Row({ space: 18 }) {
          Scroll() {
            this.SourcePane();
          }
          .width(this.sizeClass === WindowSizeClass.EXPANDED ? '44%' : '46%')
          .height('100%')
          .scrollBar(BarState.Off);

          Divider().vertical(true).height('100%').color(AppTheme.DIVIDER);

          Scroll() {
            this.CandidatePane();
          }
          .layoutWeight(1)
          .height('100%')
          .scrollBar(BarState.Off);
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top);
      }
    }
    .width('100%')
    .height('100%')
    .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING)
    .backgroundColor(AppTheme.BACKGROUND)
    .onAppear(() => this.syncDraftFromStore());
  }
}
