import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { CandidateAssignment, RawHomeworkImport, Subject } from '../../../domain/model/HomeworkModels';

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

  private saveCandidate(candidate: CandidateAssignment): void {
    if (HomeworkStore.instance.updateCandidate(candidate)) {
      this.localRevision++;
      this.onStoreChanged();
    }
  }

  private updateSubject(item: CandidateAssignment, subject: Subject): void {
    this.saveCandidate({
      id: item.id,
      subject: subject,
      title: item.title,
      instruction: item.instruction,
      textbookRef: item.textbookRef,
      dueText: item.dueText,
      sourceEvidence: item.sourceEvidence,
      confidence: item.confidence
    });
  }

  private updateTitle(item: CandidateAssignment, title: string): void {
    this.saveCandidate({
      id: item.id,
      subject: item.subject,
      title: title,
      instruction: title,
      textbookRef: item.textbookRef,
      dueText: item.dueText,
      sourceEvidence: item.sourceEvidence,
      confidence: item.confidence
    });
  }

  private updateDueText(item: CandidateAssignment, dueText: string): void {
    this.saveCandidate({
      id: item.id,
      subject: item.subject,
      title: item.title,
      instruction: item.instruction,
      textbookRef: item.textbookRef,
      dueText: dueText,
      sourceEvidence: item.sourceEvidence,
      confidence: item.confidence
    });
  }

  private updateTextbookRef(item: CandidateAssignment, textbookRef: string): void {
    this.saveCandidate({
      id: item.id,
      subject: item.subject,
      title: item.title,
      instruction: item.instruction,
      textbookRef: textbookRef,
      dueText: item.dueText,
      sourceEvidence: item.sourceEvidence,
      confidence: item.confidence
    });
  }

  private addCandidate(): void {
    let raw = this.rawImport();
    let candidate: CandidateAssignment = {
      id: `manual-${Date.now()}`,
      subject: Subject.CHINESE,
      title: '新作业',
      instruction: '新作业',
      textbookRef: '待家长确认',
      dueText: '今天',
      sourceEvidence: {
        sourceLabel: raw.sourceLabel.length > 0 ? raw.sourceLabel : '家长手工新增',
        excerpt: '家长手工新增'
      },
      confidence: 1.0
    };
    if (HomeworkStore.instance.addCandidate(candidate)) {
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
  private SubjectChip(item: CandidateAssignment, subject: Subject) {
    Text(subject)
      .fontSize(12)
      .fontColor(item.subject === subject ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(item.subject === subject ? AppTheme.PRIMARY_SOFT : '#F7F8FA')
      .borderRadius(12)
      .onClick(() => this.updateSubject(item, subject));
  }

  @Builder
  private CandidateEditor(item: CandidateAssignment) {
    Column({ space: 10 }) {
      Row() {
        Text(item.confidence < 0.8 ? '请重点确认' : '已识别')
          .fontSize(12)
          .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUCCESS);
        Blank();
        Text('删除')
          .fontSize(12)
          .fontColor(AppTheme.DANGER)
          .onClick(() => this.removeCandidate(item.id));
      }
      .width('100%');

      Text('学科').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      Row({ space: 8 }) {
        this.SubjectChip(item, Subject.CHINESE);
        this.SubjectChip(item, Subject.MATH);
        this.SubjectChip(item, Subject.ENGLISH);
      }
      .width('100%');

      Text('作业标题').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: item.title })
        .width('100%')
        .height(44)
        .backgroundColor('#F7F8FA')
        .onChange((value: string) => this.updateTitle(item, value));

      Text('截止时间').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: item.dueText })
        .width('100%')
        .height(44)
        .backgroundColor('#F7F8FA')
        .onChange((value: string) => this.updateDueText(item, value));

      Text('教材 / 页码').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: item.textbookRef })
        .width('100%')
        .height(44)
        .backgroundColor('#F7F8FA')
        .onChange((value: string) => this.updateTextbookRef(item, value));

      Column({ space: 4 }) {
        Text('老师原文').width('100%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(item.sourceEvidence.excerpt).width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(10)
      .backgroundColor(item.confidence < 0.8 ? '#FFF8E7' : '#F7F8FA')
      .borderRadius(10);
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

      Button('＋ 手工新增一项')
        .width('100%')
        .height(44)
        .backgroundColor(AppTheme.PRIMARY_SOFT)
        .fontColor(AppTheme.PRIMARY)
        .onClick(() => this.addCandidate());

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
          Text('检查学科、标题、截止时间和教材信息，确认后再进入学生作业').fontSize(13).fontColor(AppTheme.SUBTEXT);
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
