import { HomeworkImportService } from '../../../application/import/HomeworkImportService';
import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { CandidateAssignment, RawHomeworkImport } from '../../../domain/model/HomeworkModels';

@Component
export struct HomeworkImportPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private showCompactCandidates: boolean = false;
  @State private parseBusy: boolean = false;
  @State private parseMessage: string = '';
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

  private async reparse(): Promise<void> {
    if (this.parseBusy) {
      return;
    }
    this.parseBusy = true;
    let count = await HomeworkImportService.instance.reparseCurrentImport();
    this.parseBusy = false;
    this.parseMessage = count > 0 ? `Mock Pipeline 已重新生成 ${count} 项候选作业` : '解析流水线当前不可用';
    this.onStoreChanged();
    if (this.sizeClass === WindowSizeClass.COMPACT && count > 0) {
      this.showCompactCandidates = true;
    }
  }

  @Builder
  private SourcePane() {
    Column({ space: 12 }) {
      Text('老师原始内容').width('100%').fontSize(20).fontWeight(FontWeight.Bold);
      Text(this.rawImport().rawText)
        .width('100%')
        .padding(16)
        .fontSize(15)
        .lineHeight(24)
        .fontColor(AppTheme.TEXT)
        .backgroundColor('#F7F8FA')
        .borderRadius(14);
      Text('来源：' + this.rawImport().sourceLabel)
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        Button('分享导入').layoutWeight(1);
        Button('截图 OCR').layoutWeight(1);
      }
      .width('100%');
      Row({ space: 8 }) {
        Button('粘贴文本').layoutWeight(1);
        Button('上传文件').layoutWeight(1);
      }
      .width('100%');

      Button(this.parseBusy ? '解析中…' : '模拟重新解析')
        .width('100%')
        .height(44)
        .enabled(!this.parseBusy)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .onClick(() => this.reparse());

      if (this.parseMessage.length > 0) {
        Text(this.parseMessage)
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.SUCCESS);
      }

      if (this.sizeClass === WindowSizeClass.COMPACT) {
        Button('查看 AI 解析结果')
          .width('100%')
          .height(48)
          .backgroundColor(AppTheme.PRIMARY)
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
        Text('AI 解析结果').fontSize(20).fontWeight(FontWeight.Bold);
        Blank();
        Text(`${this.candidates().length} 项`).fontSize(13).fontColor(AppTheme.SUCCESS);
      }
      .width('100%');

      if (this.candidates().length === 0) {
        Text('当前没有待确认候选。可点击“模拟重新解析”通过 Import Pipeline 重新生成。')
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
            Text('证据：' + item.sourceEvidence.excerpt)
              .width('100%')
              .fontSize(12)
              .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUBTEXT)
              .backgroundColor(item.confidence < 0.8 ? '#FFF7E6' : '#F7F8FA')
              .padding(10)
              .borderRadius(10);
            if (item.confidence < 0.8) {
              Text('需要家长确认教材/页码').fontSize(12).fontColor(AppTheme.WARNING);
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor(AppTheme.SURFACE)
          .borderRadius(14)
          .border({ width: 1, color: AppTheme.BORDER });
        }, (item: CandidateAssignment) => item.id);

        Button('进入家长确认')
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
          Text('导入老师作业').fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('AI 只负责整理，发布前由家长确认').fontSize(13).fontColor(AppTheme.SUBTEXT);
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
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
