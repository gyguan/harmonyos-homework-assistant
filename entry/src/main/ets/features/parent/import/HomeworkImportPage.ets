import { HomeworkImportService } from '../../../application/import/HomeworkImportService';
import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { HomeworkImageImportResult } from '../../../domain/model/ImportModels';
import { CandidateAssignment, RawHomeworkImport } from '../../../domain/model/HomeworkModels';

@Component
export struct HomeworkImportPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private showCompactCandidates: boolean = false;
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
    }
  }

  private async parseTypedText(): Promise<void> {
    if (this.parseBusy) {
      return;
    }
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
      let count = await HomeworkImportService.instance.parseText(text);
      if (count > 0) {
        this.onStoreChanged();
        this.parseMessage = `已整理出 ${count} 项作业，请确认后发布`;
        if (this.sizeClass === WindowSizeClass.COMPACT) {
          this.showCompactCandidates = true;
        }
      } else {
        this.parseMessage = '暂时没有拆出明确作业，请检查文字中是否包含学科和具体任务';
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
    if (this.parseBusy) {
      return;
    }
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
      this.onStoreChanged();
      if (result.candidateCount > 0) {
        this.parseMessage = `已识别并整理出 ${result.candidateCount} 项作业，请确认后发布`;
        if (this.sizeClass === WindowSizeClass.COMPACT) {
          this.showCompactCandidates = true;
        }
      } else {
        this.parseMessage = '文字识别成功，但暂时没有拆出明确作业。你可以修改文字后重新整理。';
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
        Text(this.parseError ? '!' : '✓')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.parseError ? AppTheme.DANGER : AppTheme.SUCCESS);
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
  private SourcePane() {
    Column({ space: 14 }) {
      Column({ space: 5 }) {
        Text('老师原始内容')
          .width('100%')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('粘贴文字，或从相册选择截图。小伴会先整理，再由家长确认。')
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);

      TextArea({
        placeholder: '例如：\n1. 语文背诵第12课\n2. 语文完成练习册P35\n3. 数学口算20题\n4. 英语听读U4，明天检查',
        text: this.textDraft
      })
        .width('100%')
        .height(196)
        .fontSize(15)
        .lineHeight(22)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => {
          this.textDraft = value;
        });

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

      Row({ space: 10 }) {
        Divider().layoutWeight(1).color(AppTheme.DIVIDER);
        Text('或者').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
        Divider().layoutWeight(1).color(AppTheme.DIVIDER);
      }
      .width('100%');

      Button(this.parseBusy ? '正在识别…' : '从相册选择作业截图', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(!this.parseBusy)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .onClick(() => this.selectScreenshot());

      if (this.rawImport().sourceLabel.length > 0 && this.rawImport().rawText.length > 0) {
        Text('最近来源 · ' + this.rawImport().sourceLabel)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }

      this.FeedbackBanner();

      if (this.sizeClass === WindowSizeClass.COMPACT && this.candidates().length > 0) {
        Button(`查看整理结果 · ${this.candidates().length} 项`, { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_EMPHASIS)
          .fontColor(AppTheme.TEXT)
          .onClick(() => this.showCompactCandidates = true);
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private CandidatePane() {
    Column({ space: AppTheme.ITEM_GAP }) {
      if (this.sizeClass === WindowSizeClass.COMPACT) {
        Text('‹ 返回原始内容')
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.showCompactCandidates = false);
      }

      Row() {
        Text('整理结果')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.candidates().length} 项`)
          .fontSize(13)
          .fontColor(this.candidates().length > 0 ? AppTheme.SUCCESS : AppTheme.SUBTEXT);
      }
      .width('100%');

      if (this.candidates().length === 0) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.checkmark_square'))
            .fontSize(26)
            .fontColor([AppTheme.TERTIARY_TEXT]);
          Text('还没有待确认作业')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('整理老师文字或截图后，结果会显示在这里。')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .padding(24)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      } else {
        ForEach(this.candidates(), (item: CandidateAssignment) => {
          Column({ space: 10 }) {
            Row() {
              Text(item.subject)
                .fontSize(AppTheme.CAPTION_SIZE)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.PRIMARY)
                .padding({ left: 9, right: 9, top: 5, bottom: 5 })
                .backgroundColor(AppTheme.PRIMARY_SOFT)
                .borderRadius(AppTheme.CHIP_RADIUS);
              Blank();
              Text(item.dueText).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
            }
            .width('100%');
            Text(item.title)
              .width('100%')
              .fontSize(AppTheme.CARD_TITLE_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text('原文 · ' + item.sourceEvidence.excerpt)
              .width('100%')
              .fontSize(AppTheme.CAPTION_SIZE)
              .lineHeight(18)
              .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUBTEXT)
              .backgroundColor(item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE_SUBTLE)
              .padding(11)
              .borderRadius(AppTheme.CONTROL_RADIUS);
            if (item.confidence < 0.8) {
              Text('识别置信度较低，请重点确认')
                .fontSize(AppTheme.CAPTION_SIZE)
                .fontColor(AppTheme.WARNING);
            }
          }
          .width('100%')
          .padding(AppTheme.CARD_PADDING)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(AppTheme.CARD_RADIUS);
        }, (item: CandidateAssignment) => item.id);

        Button('确认这些作业', { type: ButtonType.Normal })
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
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text('收作业')
            .fontSize(AppTheme.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text('老师内容 → 智能整理 → 家长确认')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 20 }) {
            Column() { this.SourcePane(); }.width('45%');
            Column() { this.CandidatePane(); }.layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else if (this.sizeClass === WindowSizeClass.COMPACT) {
          if (this.showCompactCandidates) {
            this.CandidatePane();
          } else {
            this.SourcePane();
          }
        } else {
          this.SourcePane();
          this.CandidatePane();
        }
      }
      .width('100%')
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND)
    .onAppear(() => this.syncDraftFromStore());
  }
}
