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
        this.parseMessage = '文字识别成功，但暂时没有拆出明确作业。你可以直接修改上方文字后再点“智能整理作业”';
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
  private SourcePane() {
    Column({ space: 12 }) {
      Text('老师原始内容').width('100%').fontSize(20).fontWeight(FontWeight.Bold);
      Text('直接粘贴老师发来的文字，或从相册选择截图。小伴会把一段内容拆成多项作业。')
        .width('100%')
        .fontSize(13)
        .lineHeight(20)
        .fontColor(AppTheme.SUBTEXT);

      TextArea({
        placeholder: '例如：\n1. 语文背诵第12课\n2. 语文完成练习册P35\n3. 数学口算20题\n4. 数学练习册P32\n5. 英语听读U4，明天检查',
        text: this.textDraft
      })
        .width('100%')
        .height(190)
        .fontSize(15)
        .lineHeight(22)
        .backgroundColor('#F7F8FA')
        .borderRadius(14)
        .onChange((value: string) => {
          this.textDraft = value;
        });

      Button(this.parseBusy ? '正在整理…' : '智能整理作业')
        .width('100%')
        .height(48)
        .enabled(!this.parseBusy)
        .backgroundColor(AppTheme.PRIMARY)
        .onClick(() => this.parseTypedText());

      Row() {
        Blank();
        Text('或者').fontSize(12).fontColor(AppTheme.SUBTEXT);
        Blank();
      }
      .width('100%');

      Button(this.parseBusy ? '正在识别…' : '从相册选择作业截图')
        .width('100%')
        .height(44)
        .enabled(!this.parseBusy)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .onClick(() => this.selectScreenshot());

      if (this.rawImport().sourceLabel.length > 0 && this.rawImport().rawText.length > 0) {
        Text('最近来源：' + this.rawImport().sourceLabel)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
      }

      if (this.parseMessage.length > 0) {
        Text(this.parseMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(this.parseError ? AppTheme.DANGER : AppTheme.SUCCESS);
      }

      if (this.sizeClass === WindowSizeClass.COMPACT && this.candidates().length > 0) {
        Button('查看整理结果')
          .width('100%')
          .height(44)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.showCompactCandidates = true);
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  @Builder
  private CandidatePane() {
    Column({ space: 10 }) {
      if (this.sizeClass === WindowSizeClass.COMPACT) {
        Text('‹ 返回原始内容')
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.showCompactCandidates = false);
      }

      Row() {
        Text('整理结果').fontSize(20).fontWeight(FontWeight.Bold);
        Blank();
        Text(`${this.candidates().length} 项`).fontSize(13).fontColor(AppTheme.SUCCESS);
      }
      .width('100%');

      if (this.candidates().length === 0) {
        Text('还没有待确认作业。粘贴老师文字并点“智能整理作业”，或选择一张作业截图。')
          .width('100%')
          .padding(16)
          .fontSize(14)
          .fontColor(AppTheme.SUBTEXT)
          .backgroundColor('#F7F8FA')
          .borderRadius(14);
      } else {
        ForEach(this.candidates(), (item: CandidateAssignment) => {
          Column({ space: 8 }) {
            Row() {
              Text(item.subject).fontSize(12).fontColor(AppTheme.PRIMARY);
              Blank();
              Text(item.dueText).fontSize(12).fontColor(AppTheme.SUBTEXT);
            }
            .width('100%');
            Text(item.title).width('100%').fontSize(16).fontWeight(FontWeight.Medium);
            Text('原文：' + item.sourceEvidence.excerpt)
              .width('100%')
              .fontSize(12)
              .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUBTEXT)
              .backgroundColor(item.confidence < 0.8 ? '#FFF7E6' : '#F7F8FA')
              .padding(10)
              .borderRadius(10);
            if (item.confidence < 0.8) {
              Text('识别置信度较低，请家长重点确认').fontSize(12).fontColor(AppTheme.WARNING);
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(14)
          .border({ width: 1, color: AppTheme.BORDER });
        }, (item: CandidateAssignment) => item.id);

        Button('确认这些作业')
          .width('100%')
          .height(48)
          .backgroundColor(AppTheme.PRIMARY)
          .onClick(() => this.onOpenConfirmation());
      }
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 4 }) {
          Text('收作业').fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('粘贴老师文字或选择截图 → 智能拆分 → 家长确认').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 18 }) {
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
      .padding(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND)
    .onAppear(() => this.syncDraftFromStore());
  }
}
