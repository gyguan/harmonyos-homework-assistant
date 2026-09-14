import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { CandidateAssignment, RawHomeworkImport } from '../../../domain/model/HomeworkModels';

@Component
export struct HomeworkConfirmationPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  onBack: () => void = () => {};
  onPublished: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private candidates(): CandidateAssignment[] {
    let currentRevision = this.revision + this.localRevision;
    return HomeworkStore.instance.getCandidates();
  }

  private rawImport(): RawHomeworkImport {
    let currentRevision = this.revision + this.localRevision;
    return HomeworkStore.instance.getRawImport();
  }

  private updateTitle(candidateId: string, title: string): void {
    if (HomeworkStore.instance.updateCandidateTitle(candidateId, title)) {
      this.localRevision++;
      this.onStoreChanged();
    }
  }

  private removeCandidate(candidateId: string): void {
    if (HomeworkStore.instance.removeCandidate(candidateId)) {
      this.localRevision++;
      this.onStoreChanged();
    }
  }

  private publish(): void {
    let count = HomeworkStore.instance.publishCandidates();
    if (count > 0) {
      this.localRevision++;
      this.onStoreChanged();
      this.onPublished();
    }
  }

  @Builder
  private SourcePane() {
    Column({ space: 10 }) {
      Text('原始内容').width('100%').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
      Text(this.rawImport().rawText)
        .width('100%')
        .padding(16)
        .fontSize(14)
        .lineHeight(23)
        .fontColor(AppTheme.TEXT)
        .backgroundColor('#F7F8FA')
        .borderRadius(14);
      Text('来源：' + this.rawImport().sourceLabel)
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.SUBTEXT);
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  @Builder
  private CandidateEditor(item: CandidateAssignment) {
    Column({ space: 10 }) {
      Row() {
        Text(item.subject)
          .fontSize(12)
          .fontColor(AppTheme.PRIMARY)
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(10);
        Blank();
        Text(item.confidence < 0.8 ? '低置信度' : '已识别')
          .fontSize(12)
          .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUCCESS);
      }
      .width('100%');

      Text('作业标题').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: item.title })
        .width('100%')
        .height(44)
        .backgroundColor('#F7F8FA')
        .onChange((value: string) => this.updateTitle(item.id, value));

      Text(item.instruction).width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
      Text(item.textbookRef).width('100%').fontSize(13).fontColor(AppTheme.PRIMARY);
      Text(`截止：${item.dueText}`).width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);

      Column({ space: 4 }) {
        Text('Source Evidence').width('100%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(item.sourceEvidence.excerpt).width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(10)
      .backgroundColor(item.confidence < 0.8 ? '#FFF8E7' : '#F7F8FA')
      .borderRadius(10);

      Text('删除这项候选')
        .width('100%')
        .fontSize(12)
        .fontColor(AppTheme.DANGER)
        .onClick(() => this.removeCandidate(item.id));
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(16)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  @Builder
  private CandidateList() {
    Column({ space: 12 }) {
      Row() {
        Text('待确认作业').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.candidates().length} 项`).fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      ForEach(this.candidates(), (item: CandidateAssignment) => {
        this.CandidateEditor(item);
      }, (item: CandidateAssignment) => item.id);

      Button(`确认并发布 ${this.candidates().length} 项作业`)
        .width('100%')
        .height(48)
        .enabled(this.candidates().length > 0)
        .backgroundColor(this.candidates().length > 0 ? AppTheme.PRIMARY : '#C9D1DD')
        .onClick(() => this.publish());
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Row() {
          Text('‹ 返回导入')
            .fontSize(14)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => this.onBack());
          Blank();
          Text('发布前确认').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');

        Column({ space: 4 }) {
          Text('确认老师作业').fontSize(26).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text('AI 整理结果必须经过家长确认后才会进入学生今日作业').fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 18 }) {
            Column() { this.SourcePane(); }.width('40%');
            Column() { this.CandidateList(); }.layoutWeight(1);
          }
          .width('100%')
          .alignItems(VerticalAlign.Top);
        } else {
          this.SourcePane();
          this.CandidateList();
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
