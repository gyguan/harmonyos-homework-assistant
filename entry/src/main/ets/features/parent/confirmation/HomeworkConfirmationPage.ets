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
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: subject, title: item.title,
      instruction: item.instruction, textbookRef: item.textbookRef, dueText: item.dueText,
      sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private updateTitle(item: CandidateAssignment, title: string): void {
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: item.subject, title: title,
      instruction: title, textbookRef: item.textbookRef, dueText: item.dueText,
      sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private updateDueText(item: CandidateAssignment, dueText: string): void {
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: item.subject, title: item.title,
      instruction: item.instruction, textbookRef: item.textbookRef, dueText: dueText,
      sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private updateTextbookRef(item: CandidateAssignment, textbookRef: string): void {
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: item.subject, title: item.title,
      instruction: item.instruction, textbookRef: textbookRef, dueText: item.dueText,
      sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private addCandidate(): void {
    let raw = this.rawImport();
    let candidate: CandidateAssignment = {
      id: `manual-${Date.now()}`,
      studentId: HomeworkStore.instance.getActiveStudentId(),
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
    Column({ space: 12 }) {
      Row() {
        Text('老师原文')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(this.rawImport().sourceLabel)
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.TERTIARY_TEXT);
      }
      .width('100%');
      Text(this.rawImport().rawText)
        .width('100%')
        .padding(15)
        .fontSize(AppTheme.BODY_SIZE)
        .lineHeight(23)
        .fontColor(AppTheme.TEXT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private SubjectChip(item: CandidateAssignment, subject: Subject) {
    Text(subject)
      .fontSize(AppTheme.CAPTION_SIZE)
      .fontWeight(item.subject === subject ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(item.subject === subject ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(item.subject === subject ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .onClick(() => this.updateSubject(item, subject));
  }

  @Builder
  private FieldLabel(label: string) {
    Text(label)
      .width('100%')
      .fontSize(AppTheme.CAPTION_SIZE)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.SUBTEXT);
  }

  @Builder
  private CandidateEditor(item: CandidateAssignment) {
    Column({ space: 11 }) {
      Row() {
        Text(item.confidence < 0.8 ? '请重点确认' : '识别结果')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUCCESS)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SUCCESS_SOFT)
          .borderRadius(AppTheme.CHIP_RADIUS);
        Blank();
        Text('删除')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.DANGER)
          .padding({ left: 8, right: 8, top: 6, bottom: 6 })
          .onClick(() => this.removeCandidate(item.id));
      }
      .width('100%');

      this.FieldLabel('学科');
      Row({ space: 8 }) {
        this.SubjectChip(item, Subject.CHINESE);
        this.SubjectChip(item, Subject.MATH);
        this.SubjectChip(item, Subject.ENGLISH);
      }
      .width('100%');

      this.FieldLabel('作业标题');
      TextInput({ text: item.title })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateTitle(item, value));

      this.FieldLabel('截止时间');
      TextInput({ text: item.dueText })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateDueText(item, value));

      this.FieldLabel('教材 / 页码');
      TextInput({ text: item.textbookRef })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateTextbookRef(item, value));

      Column({ space: 5 }) {
        Text('老师原文')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(item.sourceEvidence.excerpt)
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .lineHeight(18)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(12)
      .backgroundColor(item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private CandidateList() {
    Column({ space: AppTheme.ITEM_GAP }) {
      Row() {
        Text('待确认作业')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        Text(`${this.candidates().length} 项`)
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      ForEach(this.candidates(), (item: CandidateAssignment) => {
        this.CandidateEditor(item);
      }, (item: CandidateAssignment) => item.id);

      Button('＋ 手工新增一项', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_EMPHASIS)
        .fontColor(AppTheme.TEXT)
        .onClick(() => this.addCandidate());

      Button(`确认并发布 ${this.candidates().length} 项作业`, { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(this.candidates().length > 0)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.candidates().length > 0 ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => this.publish());
    }
    .width('100%');
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Row() {
          Text('‹ 返回')
            .fontSize(14)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => this.onBack());
          Blank();
          Text('发布前确认')
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
        .width('100%');

        Column({ space: 5 }) {
          Text('确认老师作业')
            .fontSize(AppTheme.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text(`${HomeworkStore.instance.getStudent().name} · ${HomeworkStore.instance.getStudent().className}`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start);

        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 20 }) {
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
      .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
