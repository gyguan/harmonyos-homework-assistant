import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { CandidateAssignment, Subject } from '../../../domain/model/HomeworkModels';
import { HomeworkConfirmationViewModel } from './HomeworkConfirmationViewModel';

@Component
export struct HomeworkConfirmationPage {
  // Compatibility prop from AppShell. Confirmation layout no longer branches on this value.
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  @State private editingCandidateId: string = '';
  @State private publishing: boolean = false;
  @State private publishMessage: string = '';
  @State private publishError: boolean = false;
  onBack: () => void = () => {};
  onPublished: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: HomeworkConfirmationViewModel = new HomeworkConfirmationViewModel();

  aboutToAppear(): void {
    let items = this.candidates();
    if (items.length > 0 && this.editingCandidateId.length === 0) this.editingCandidateId = items[0].id;
  }

  private touchRevision(): number { return this.revision + this.localRevision; }

  private candidates(): CandidateAssignment[] {
    let currentRevision = this.touchRevision();
    if (currentRevision < 0) return [];
    return this.viewModel.candidates();
  }

  private editingCandidate(): CandidateAssignment | null {
    for (let item of this.candidates()) if (item.id === this.editingCandidateId) return item;
    return null;
  }

  private saveCandidate(candidate: CandidateAssignment): void {
    if (!this.viewModel.updateCandidate(candidate)) return;
    this.localRevision++;
    this.onStoreChanged();
  }

  private copy(item: CandidateAssignment, subject: Subject = item.subject, title: string = item.title,
    instruction: string = item.instruction, dueText: string = item.dueText,
    textbookRef: string = item.textbookRef, expectedMinutes: number = item.expectedMinutes): CandidateAssignment {
    return {
      id: item.id, studentId: item.studentId, subject: subject, title: title, instruction: instruction,
      textbookRef: textbookRef, dueText: dueText, expectedMinutes: expectedMinutes,
      sourceEvidence: { sourceLabel: item.sourceEvidence.sourceLabel, excerpt: item.sourceEvidence.excerpt },
      confidence: item.confidence
    };
  }

  private updateSubject(item: CandidateAssignment, subject: Subject): void {
    this.saveCandidate(this.copy(item, subject));
  }

  private updateTitle(item: CandidateAssignment, title: string): void {
    this.saveCandidate(this.copy(item, item.subject, title, title));
  }

  private updateInstruction(item: CandidateAssignment, instruction: string): void {
    this.saveCandidate(this.copy(item, item.subject, item.title, instruction));
  }

  private updateDueText(item: CandidateAssignment, dueText: string): void {
    this.saveCandidate(this.copy(item, item.subject, item.title, item.instruction, dueText));
  }

  private updateTextbookRef(item: CandidateAssignment, textbookRef: string): void {
    this.saveCandidate(this.copy(item, item.subject, item.title, item.instruction, item.dueText, textbookRef));
  }

  private updateExpectedMinutes(item: CandidateAssignment, value: string): void {
    let minutes = Math.round(Number(value));
    if (!Number.isFinite(minutes)) return;
    if (minutes < 1) minutes = 1;
    if (minutes > 240) minutes = 240;
    this.saveCandidate(this.copy(item, item.subject, item.title, item.instruction,
      item.dueText, item.textbookRef, minutes));
  }

  private addCandidate(): void {
    let candidate = this.viewModel.addCandidate();
    if (candidate === null) return;
    this.editingCandidateId = candidate.id;
    this.localRevision++;
    this.onStoreChanged();
  }

  private removeCandidate(candidateId: string): void {
    if (!this.viewModel.removeCandidate(candidateId)) return;
    this.localRevision++;
    let items = this.candidates();
    this.editingCandidateId = items.length > 0 ? items[0].id : '';
    this.onStoreChanged();
  }

  private async publish(): Promise<void> {
    if (this.publishing || this.candidates().length === 0) return;
    this.publishing = true;
    this.publishMessage = '';
    this.publishError = false;
    try {
      let result = await this.viewModel.publish();
      this.localRevision++;
      this.onStoreChanged();
      this.publishMessage = `已发布 ${result.publishedCount} 项作业`;
      this.onPublished();
    } catch (error) {
      this.publishError = true;
      let message = `${error}`;
      this.publishMessage = message.indexOf('离线') >= 0 ? '当前离线，待确认作业已保留；联网后可继续发布。' :
        '发布未完成，全部待确认作业均已保留，请检查网络或刷新后重试。';
    } finally {
      this.publishing = false;
    }
  }

  @Builder
  private SubjectChip(item: CandidateAssignment, subject: Subject) {
    Text(subject)
      .fontSize(13)
      .fontWeight(item.subject === subject ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(item.subject === subject ? AppTheme.PRIMARY : AppTheme.SUBTEXT)
      .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
      .padding({ left: 13, right: 13, top: 9, bottom: 9 })
      .backgroundColor(item.subject === subject ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_EMPHASIS)
      .borderRadius(AppTheme.CHIP_RADIUS)
      .accessibilityRole(AccessibilityRoleType.BUTTON)
      .accessibilityText(item.subject === subject ? `${subject}，已选择` : subject)
      .onClick(() => this.updateSubject(item, subject));
  }

  @Builder
  private CandidateCard(item: CandidateAssignment) {
    Column({ space: 8 }) {
      Row() {
        Row({ space: 7 }) {
          Text(item.subject).fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
          if (item.confidence < 0.8) {
            Text('重点确认').fontSize(10).fontColor(AppTheme.WARNING)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor(AppTheme.WARNING_SOFT).borderRadius(AppTheme.CHIP_RADIUS);
          }
        }
        Blank();
        Text(item.dueText).fontSize(12).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%');
      Text(item.title).width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT).maxLines(2);
      Text(`预计 ${item.expectedMinutes} 分钟 · ${item.textbookRef.length > 0 ? item.textbookRef : '未设置教材页码'}`)
        .width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT).maxLines(1);
      Text(`来源证据 · ${item.sourceEvidence.excerpt}`)
        .width('100%').fontSize(11).lineHeight(17)
        .fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.TERTIARY_TEXT).maxLines(2);
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.editingCandidateId === item.id ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)
    .border({ width: this.editingCandidateId === item.id ? 1 : 0,
      color: this.editingCandidateId === item.id ? AppTheme.PRIMARY : Color.Transparent })
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(`${item.subject}，${item.title}，打开编辑`)
    .onClick(() => this.editingCandidateId = item.id);
  }

  @Builder
  private CandidateEditor(item: CandidateAssignment) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text(item.confidence < 0.8 ? '重点确认' : '核对作业')
            .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Text(item.confidence < 0.8 ? '识别置信度较低，请对照老师原文逐项核对。' : '发布前确认任务内容与时间。')
            .fontSize(12).fontColor(item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
        Text('删除').fontSize(13).fontColor(AppTheme.DANGER)
          .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText(`删除${item.title}`)
          .onClick(() => this.removeCandidate(item.id));
      }
      .width('100%');

      Row({ space: 8 }) {
        this.SubjectChip(item, Subject.CHINESE);
        this.SubjectChip(item, Subject.MATH);
        this.SubjectChip(item, Subject.ENGLISH);
      }
      .width('100%');

      Text('作业标题').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: item.title }).width('100%').height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateTitle(item, value));

      Text('老师要求').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextArea({ text: item.instruction }).width('100%').height(92)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateInstruction(item, value));

      Text('截止时间').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: item.dueText }).width('100%').height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateDueText(item, value));

      Text('预计用时（分钟）').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: `${item.expectedMinutes}` }).width('100%').height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateExpectedMinutes(item, value));

      Text('教材 / 页码').width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
      TextInput({ text: item.textbookRef }).width('100%').height(AppTheme.INPUT_HEIGHT)
        .backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.updateTextbookRef(item, value));

      Column({ space: 5 }) {
        Text(item.sourceEvidence.sourceLabel.length > 0 ? item.sourceEvidence.sourceLabel : '老师原文')
          .width('100%').fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Text(item.sourceEvidence.excerpt).width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(13)
      .backgroundColor(item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
    .width('100%');
  }

  @Builder
  private PublishFeedback() {
    if (this.publishMessage.length > 0) {
      Text(this.publishMessage).width('100%').fontSize(12).lineHeight(18)
        .fontColor(this.publishError ? AppTheme.DANGER : AppTheme.SUCCESS)
        .padding(10)
        .backgroundColor(this.publishError ? AppTheme.DANGER_SOFT : AppTheme.SUCCESS_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Column({ space: 14 }) {
            DeepPageHeader({
              title: '确认发布',
              subtitle: `${this.candidates().length} 项待确认`,
              backAccessibilityText: '返回导入',
              onBack: () => this.onBack()
            });

            Column({ space: 4 }) {
              Text('发布前最后核对').width('100%')
                .fontSize(AppTheme.PHONE_SECTION_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
              Text('低置信字段和来源证据优先确认；发布采用整批原子提交，不会出现只发布一半。')
                .width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.SUBTEXT);
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start);

            if (this.candidates().length === 0) {
              Column({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(30).fontColor([AppTheme.SUCCESS]);
                Text('没有待确认作业').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
                Text('返回导入页重新整理老师原文。').fontSize(13).fontColor(AppTheme.SUBTEXT);
              }
              .width('100%')
              .padding({ top: 30, bottom: 30 });
            } else {
              Column({ space: 7 }) {
                ForEach(this.candidates(), (item: CandidateAssignment) => { this.CandidateCard(item); },
                  (item: CandidateAssignment) => item.id);
              }
              .width('100%');

              Button('＋ 手工新增一项', { type: ButtonType.Normal })
                .width('100%').height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.TEXT)
                .onClick(() => this.addCandidate());

              if (this.editingCandidate() !== null) {
                Column() { this.CandidateEditor(this.editingCandidate()!); }
                  .width('100%').padding(AppTheme.PHONE_CARD_PADDING)
                  .backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.PHONE_CARD_RADIUS);
              }

              this.PublishFeedback();

              Button(this.publishing ? '正在发布…' : `确认并发布 ${this.candidates().length} 项`,
                { type: ButtonType.Normal })
                .width('100%').height(AppTheme.BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .enabled(!this.publishing && this.candidates().length > 0)
                .fontSize(15).fontWeight(FontWeight.Medium)
                .backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
                .onClick(() => { void this.publish(); });
            }
          }
          .width('100%')
          .constraintSize({ maxWidth: AppTheme.CONFIRMATION_READABLE_MAX_WIDTH })
          .padding({ left: AppTheme.PHONE_PAGE_PADDING, right: AppTheme.PHONE_PAGE_PADDING,
            top: AppTheme.DEEP_PAGE_TOP_PADDING, bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING });
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center);
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
