import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { CandidateAssignment, RawHomeworkImport, Subject } from '../../../domain/model/HomeworkModels';

@Component
export struct HomeworkConfirmationPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  @State private editingCandidateId: string = '';
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

  private editingCandidate(): CandidateAssignment | null {
    if (this.editingCandidateId.length === 0) return null;
    for (let item of this.candidates()) {
      if (item.id === this.editingCandidateId) return item;
    }
    return null;
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
      expectedMinutes: item.expectedMinutes, sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private updateTitle(item: CandidateAssignment, title: string): void {
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: item.subject, title: title,
      instruction: title, textbookRef: item.textbookRef, dueText: item.dueText,
      expectedMinutes: item.expectedMinutes, sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private updateDueText(item: CandidateAssignment, dueText: string): void {
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: item.subject, title: item.title,
      instruction: item.instruction, textbookRef: item.textbookRef, dueText: dueText,
      expectedMinutes: item.expectedMinutes, sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private updateTextbookRef(item: CandidateAssignment, textbookRef: string): void {
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: item.subject, title: item.title,
      instruction: item.instruction, textbookRef: textbookRef, dueText: item.dueText,
      expectedMinutes: item.expectedMinutes, sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private updateExpectedMinutes(item: CandidateAssignment, value: string): void {
    let minutes = Number(value);
    if (minutes < 1) minutes = 1;
    if (minutes > 240) minutes = 240;
    minutes = Math.round(minutes);
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: item.subject, title: item.title,
      instruction: item.instruction, textbookRef: item.textbookRef, dueText: item.dueText,
      expectedMinutes: minutes, sourceEvidence: item.sourceEvidence, confidence: item.confidence });
  }

  private setExpectedMinutes(item: CandidateAssignment, minutes: number): void {
    this.saveCandidate({ id: item.id, studentId: item.studentId, subject: item.subject, title: item.title,
      instruction: item.instruction, textbookRef: item.textbookRef, dueText: item.dueText,
      expectedMinutes: minutes, sourceEvidence: item.sourceEvidence, confidence: item.confidence });
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
      expectedMinutes: 20,
      sourceEvidence: {
        sourceLabel: raw.sourceLabel.length > 0 ? raw.sourceLabel : '家长手工新增',
        excerpt: '家长手工新增'
      },
      confidence: 1.0
    };
    if (HomeworkStore.instance.addCandidate(candidate)) {
      this.localRevision++;
      this.editingCandidateId = candidate.id;
      this.onStoreChanged();
    }
  }

  private removeCandidate(candidateId: string): void {
    if (HomeworkStore.instance.removeCandidate(candidateId)) {
      if (this.editingCandidateId === candidateId) this.editingCandidateId = '';
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
  private SubjectChip(item: CandidateAssignment, subject: Subject) {
    Text(subject)
      .fontSize(13)
      .fontWeight(item.subject === subject ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(item.subject === subject ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(item.subject === subject ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(item.subject === subject ? `${subject}，已选择` : subject)
      .onClick(() => this.updateSubject(item, subject));
  }

  @Builder
  private TimeChip(item: CandidateAssignment, minutes: number) {
    Text(`${minutes} 分钟`)
      .fontSize(12)
      .fontWeight(item.expectedMinutes === minutes ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(item.expectedMinutes === minutes ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 10, right: 10, top: 10, bottom: 10 })
      .backgroundColor(item.expectedMinutes === minutes ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(item.expectedMinutes === minutes ? `${minutes}分钟，已选择` : `${minutes}分钟`)
      .onClick(() => this.setExpectedMinutes(item, minutes));
  }

  @Builder
  private FieldLabel(label: string) {
    Text(label)
      .width('100%')
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppTheme.SUBTEXT);
  }

  @Builder
  private CandidateRow(item: CandidateAssignment) {
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
        Text(item.title)
          .width('100%')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT)
          .maxLines(2);
        Row({ space: 6 }) {
          Text(item.dueText).fontSize(12).fontColor(AppTheme.SUBTEXT);
          Text('·').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
          Text(`${item.expectedMinutes} 分钟`).fontSize(12).fontColor(AppTheme.SUBTEXT);
          if (item.confidence < 0.8) {
            Text('· 请确认').fontSize(12).fontColor(AppTheme.WARNING);
          }
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
      Text('›').fontSize(22).fontColor(AppTheme.TERTIARY_TEXT);
    }
    .width('100%')
    .constraintSize({ minHeight: 60 })
    .padding(12)
    .backgroundColor(this.editingCandidateId === item.id ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
    .borderRadius(AppTheme.CONTROL_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${item.subject}，${item.title}，${item.dueText}，预计${item.expectedMinutes}分钟`)
    .onClick(() => this.editingCandidateId = item.id);
  }

  @Builder
  private CandidateList() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('待确认作业')
            .fontSize(AppTheme.SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('点击一项查看并修改详情')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Text(`${this.candidates().length} 项`)
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');

      Column({ space: 7 }) {
        ForEach(this.candidates(), (item: CandidateAssignment) => {
          this.CandidateRow(item);
        }, (item: CandidateAssignment) => item.id);
      }
      .width('100%');

      Button('＋ 手工新增一项', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_EMPHASIS)
        .fontColor(AppTheme.TEXT)
        .onClick(() => this.addCandidate());
    }
    .width('100%');
  }

  @Builder
  private CandidateEditor(item: CandidateAssignment) {
    Column({ space: 13 }) {
      Row() {
        Column({ space: 2 }) {
          Text(item.confidence < 0.8 ? '重点确认' : '编辑作业')
            .fontSize(AppTheme.SECTION_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text(item.confidence < 0.8 ? '这项识别置信度较低，请核对老师原文。' : '确认学科、任务、时间和教材信息。')
            .fontSize(12)
            .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('删除')
          .fontSize(13)
          .fontColor(AppTheme.DANGER)
          .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 8, right: 8, top: 8, bottom: 8 })
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText(`删除${item.title}`)
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

      this.FieldLabel('作业');
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

      this.FieldLabel('预计用时');
      Scroll() {
        Row({ space: 7 }) {
          this.TimeChip(item, 10);
          this.TimeChip(item, 15);
          this.TimeChip(item, 20);
          this.TimeChip(item, 30);
          this.TimeChip(item, 45);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
      TextInput({ text: `${item.expectedMinutes}` })
        .width('100%')
        .height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateExpectedMinutes(item, value));

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
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text(item.sourceEvidence.excerpt)
          .width('100%')
          .fontSize(13)
          .lineHeight(19)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(13)
      .backgroundColor(item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
    .width('100%');
  }

  @Builder
  private EditorPane() {
    if (this.editingCandidate() === null) {
      Column({ space: 9 }) {
        SymbolGlyph($r('sys.symbol.checkmark_square'))
          .fontSize(32)
          .fontColor([AppTheme.TERTIARY_TEXT]);
        Text('选择一项作业')
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('在左侧选择后，可在这里核对并修改。')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    } else {
      Scroll() {
        this.CandidateEditor(this.editingCandidate()!);
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off);
    }
  }

  @Builder
  private PublishBar() {
    Row({ space: 10 }) {
      Text(`${this.candidates().length} 项待发布`)
        .fontSize(13)
        .fontColor(AppTheme.SUBTEXT);
      Blank();
      Button('确认并发布', { type: ButtonType.Normal })
        .height(AppTheme.BUTTON_HEIGHT)
        .padding({ left: 22, right: 22 })
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(this.candidates().length > 0)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.candidates().length > 0 ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .onClick(() => this.publish());
    }
    .width('100%')
    .padding({ top: 8 });
  }

  @Builder
  private CompactLayout() {
    if (this.editingCandidate() === null) {
      Column({ space: 12 }) {
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 5 }) {
              Text('老师原文')
                .width('100%')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.SUBTEXT);
              Text(this.rawImport().rawText)
                .width('100%')
                .fontSize(13)
                .lineHeight(20)
                .fontColor(AppTheme.TEXT)
                .maxLines(4);
            }
            .width('100%')
            .padding(13)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
            this.CandidateList();
          }
          .width('100%');
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);
        this.PublishBar();
      }
      .width('100%')
      .layoutWeight(1);
    } else {
      Column({ space: 10 }) {
        Text('‹ 返回作业列表')
          .fontSize(14)
          .fontColor(AppTheme.PRIMARY)
          .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
          .padding({ left: 4, right: 8 })
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('返回作业列表')
          .onClick(() => this.editingCandidateId = '');
        Column() {
          this.EditorPane();
        }
        .width('100%')
        .layoutWeight(1);
      }
      .width('100%')
      .layoutWeight(1);
    }
  }

  @Builder
  private PadLayout() {
    Row({ space: 18 }) {
      Column({ space: 12 }) {
        Scroll() {
          Column({ space: 14 }) {
            Column({ space: 4 }) {
              Text('老师原文')
                .width('100%')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.SUBTEXT);
              Text(this.rawImport().rawText)
                .width('100%')
                .fontSize(13)
                .lineHeight(20)
                .fontColor(AppTheme.TEXT)
                .maxLines(5);
            }
            .width('100%')
            .padding(13)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
            this.CandidateList();
          }
          .width('100%');
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);
        this.PublishBar();
      }
      .width(this.sizeClass === WindowSizeClass.EXPANDED ? '38%' : '43%')
      .height('100%');

      Divider().vertical(true).height('100%').color(AppTheme.DIVIDER);

      Column() {
        this.EditorPane();
      }
      .layoutWeight(1)
      .height('100%')
      .padding(4);
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(VerticalAlign.Top);
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹')
          .width(AppTheme.MIN_TOUCH_TARGET)
          .height(AppTheme.MIN_TOUCH_TARGET)
          .fontSize(30)
          .fontColor(AppTheme.TEXT)
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('返回收作业')
          .onClick(() => this.onBack());
        Column({ space: 2 }) {
          Text('确认老师作业')
            .fontSize(AppTheme.PAGE_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text(`${HomeworkStore.instance.getStudent().name} · ${HomeworkStore.instance.getStudent().className}`)
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
        }
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%');

      if (this.sizeClass === WindowSizeClass.COMPACT) {
        this.CompactLayout();
      } else {
        this.PadLayout();
      }
    }
    .width('100%')
    .height('100%')
    .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
