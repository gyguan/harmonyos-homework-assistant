import { AppTheme } from '../../../common/theme/AppTheme';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { CandidateAssignment, Subject } from '../../../domain/model/HomeworkModels';
import { HomeworkConfirmationViewModel } from './HomeworkConfirmationViewModel';
import { ConfirmationCandidateCard, ConfirmationCandidateEditor } from './ConfirmationCandidateComponents';

@Component
export struct HomeworkConfirmationPage {
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  @State private editingCandidateId: string = '';
  @State private showEditorSheet: boolean = false;
  @State private publishing: boolean = false;
  @State private publishMessage: string = '';
  @State private publishError: boolean = false;
  onBack: () => void = () => {};
  onPublished: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: HomeworkConfirmationViewModel = new HomeworkConfirmationViewModel();

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

  private candidateRenderKey(item: CandidateAssignment): string {
    return `${item.id}|${item.subject}|${item.title}|${item.instruction}|${item.dueText}|${item.textbookRef}|${item.expectedMinutes}`;
  }

  private openEditor(candidateId: string): void {
    this.editingCandidateId = candidateId;
    this.showEditorSheet = true;
  }

  private closeEditor(): void {
    this.showEditorSheet = false;
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
    this.saveCandidate(this.copy(item, item.subject, title, item.instruction));
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

  private setExpectedMinutes(item: CandidateAssignment, minutes: number): void {
    this.saveCandidate(this.copy(item, item.subject, item.title, item.instruction,
      item.dueText, item.textbookRef, minutes));
  }

  private addCandidate(): void {
    let candidate = this.viewModel.addCandidate();
    if (candidate === null) return;
    this.localRevision++;
    this.onStoreChanged();
    this.openEditor(candidate.id);
  }

  private removeCandidate(candidateId: string): void {
    if (!this.viewModel.removeCandidate(candidateId)) return;
    this.localRevision++;
    if (this.editingCandidateId === candidateId) {
      this.editingCandidateId = '';
      this.showEditorSheet = false;
    }
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
  private CandidateEditorSheet() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('编辑作业')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          if (this.editingCandidate() !== null) {
            Text(`${this.editingCandidate()!.subject} · ${this.editingCandidate()!.title}`)
              .maxLines(1)
              .fontSize(12)
              .fontColor(AppTheme.SUBTEXT);
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('完成')
          .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.PRIMARY)
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .accessibilityText('完成编辑')
          .onClick(() => this.closeEditor());
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 8 });

      Divider().color(AppTheme.DIVIDER);

      if (this.editingCandidate() !== null) {
        Scroll() {
          ConfirmationCandidateEditor({
            item: this.editingCandidate()!,
            onDelete: (candidateId: string) => this.removeCandidate(candidateId),
            onSubjectChange: (candidate: CandidateAssignment, subject: Subject) =>
              this.updateSubject(candidate, subject),
            onTitleChange: (candidate: CandidateAssignment, value: string) =>
              this.updateTitle(candidate, value),
            onInstructionChange: (candidate: CandidateAssignment, value: string) =>
              this.updateInstruction(candidate, value),
            onDueTextChange: (candidate: CandidateAssignment, value: string) =>
              this.updateDueText(candidate, value),
            onMinutesChange: (candidate: CandidateAssignment, minutes: number) =>
              this.setExpectedMinutes(candidate, minutes),
            onTextbookRefChange: (candidate: CandidateAssignment, value: string) =>
              this.updateTextbookRef(candidate, value)
          })
          .padding({ left: 16, right: 16, top: 12, bottom: 28 });
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Auto);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.SURFACE);
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
                ForEach(this.candidates(), (item: CandidateAssignment) => {
                  ConfirmationCandidateCard({
                    item: item,
                    selected: this.showEditorSheet && this.editingCandidateId === item.id,
                    onSelect: () => this.openEditor(item.id),
                    onMinutesChange: (candidate: CandidateAssignment, minutes: number) =>
                      this.setExpectedMinutes(candidate, minutes)
                  });
                }, (item: CandidateAssignment) => this.candidateRenderKey(item));
              }
              .width('100%');

              Button('＋ 手工新增一项', { type: ButtonType.Normal })
                .width('100%').height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .borderRadius(AppTheme.CONTROL_RADIUS)
                .backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.TEXT)
                .onClick(() => this.addCandidate());

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
    .backgroundColor(AppTheme.BACKGROUND)
    .bindSheet($$this.showEditorSheet, this.CandidateEditorSheet(), {
      height: '82%',
      showClose: false,
      preferType: SheetType.BOTTOM
    });
  }
}
