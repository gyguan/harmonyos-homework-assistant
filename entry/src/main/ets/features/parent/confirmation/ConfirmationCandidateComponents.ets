import {
  HomeworkOrganizerFeedbackRemoteApi,
  HomeworkFeedbackType,
  HomeworkFeedbackInput,
  HomeworkTeacherExperienceSummary
} from '../../../application/remote/HomeworkOrganizerFeedbackRemoteApi';
import { HomeworkOrganizerRemoteApi } from '../../../application/remote/HomeworkOrganizerRemoteApi';
import { AssignmentEditChangeDetector, AssignmentEditValues } from '../../../common/state/AssignmentEditChangeDetector';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentEditForm } from '../../../components/assignment/AssignmentEditForm';
import {
  PendingAssignmentAttachment,
  PendingAssignmentAttachmentPicker
} from '../../../components/assignment/PendingAssignmentAttachmentPicker';
import { EditSheetHeader } from '../../../components/navigation/EditSheetHeader';
import { ChoiceSelectionChip } from '../../../components/selection/SelectionControls';
import { CandidateAssignment, Subject } from '../../../domain/model/HomeworkModels';

@Component
export struct CandidateDurationControl {
  @Prop item: CandidateAssignment;
  onMinutesChange: (candidate: CandidateAssignment, minutes: number) => void =
    (_candidate: CandidateAssignment, _minutes: number) => {};

  build() {
    Column({ space: 5 }) {
      Text('预计用时')
        .width('100%')
        .fontSize(AppTheme.LABEL_TITLE_SIZE)
        .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
        .fontColor(AppTheme.TERTIARY_TEXT);

      Scroll() {
        Row({ space: 6 }) {
          ChoiceSelectionChip({
            label: '10',
            selected: this.item.expectedMinutes === 10,
            compact: true,
            onSelect: () => this.onMinutesChange(this.item, 10)
          });
          ChoiceSelectionChip({
            label: '15',
            selected: this.item.expectedMinutes === 15,
            compact: true,
            onSelect: () => this.onMinutesChange(this.item, 15)
          });
          ChoiceSelectionChip({
            label: '20',
            selected: this.item.expectedMinutes === 20,
            compact: true,
            onSelect: () => this.onMinutesChange(this.item, 20)
          });
          ChoiceSelectionChip({
            label: '30',
            selected: this.item.expectedMinutes === 30,
            compact: true,
            onSelect: () => this.onMinutesChange(this.item, 30)
          });
          ChoiceSelectionChip({
            label: '45',
            selected: this.item.expectedMinutes === 45,
            compact: true,
            onSelect: () => this.onMinutesChange(this.item, 45)
          });
          Text('分钟')
            .fontSize(AppTheme.CAPTION_SIZE)
            .lineHeight(AppTheme.CAPTION_LINE_HEIGHT)
            .fontColor(AppTheme.TERTIARY_TEXT);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
    }
    .width('100%');
  }
}

@Component
export struct ConfirmationCandidateCard {
  @Prop item: CandidateAssignment;
  @Prop selected: boolean = false;
  onSelect: () => void = () => {};
  onMinutesChange: (candidate: CandidateAssignment, minutes: number) => void =
    (_candidate: CandidateAssignment, _minutes: number) => {};

  build() {
    Column({ space: 7 }) {
      Row() {
        Row({ space: 7 }) {
          Text(this.item.subject)
            .fontSize(AppTheme.META_SIZE)
            .lineHeight(AppTheme.META_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY);
          if (this.item.confidence < 0.8) {
            Text('重点确认')
              .fontSize(AppTheme.META_SIZE)
              .lineHeight(AppTheme.META_LINE_HEIGHT)
              .fontColor(AppTheme.WARNING)
              .padding({ left: 7, right: 7, top: 3, bottom: 3 })
              .backgroundColor(AppTheme.WARNING_SOFT)
              .borderRadius(AppTheme.CHIP_RADIUS);
          }
        }
        Blank();
        Text(this.item.taskDate)
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(1);
      }
      .width('100%');

      Text(this.item.title)
        .width('100%')
        .fontSize(AppTheme.CARD_TITLE_SIZE)
        .lineHeight(AppTheme.CARD_TITLE_LINE_HEIGHT)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT)
        .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
        .textOverflow({ overflow: TextOverflow.Ellipsis });

      if (this.item.textbookRef.length > 0) {
        Text(this.item.textbookRef)
          .width('100%')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }

      CandidateDurationControl({
        item: this.item,
        onMinutesChange: (candidate: CandidateAssignment, minutes: number) =>
          this.onMinutesChange(candidate, minutes)
      });

      Text(`来源 · ${this.item.sourceEvidence.excerpt}`)
        .width('100%')
        .fontSize(AppTheme.META_SIZE)
        .lineHeight(AppTheme.META_LINE_HEIGHT)
        .fontColor(this.item.confidence < 0.8 ? AppTheme.WARNING : AppTheme.TERTIARY_TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .padding(11)
    .backgroundColor(AppTheme.CARD_SURFACE)
    .border({ width: this.selected ? 1 : 0,
      color: this.selected ? AppTheme.PRIMARY : Color.Transparent })
    .borderRadius(AppTheme.CARD_RADIUS_COMPACT)
    .accessibilityGroup(true)
    .accessibilityRole(AccessibilityRoleType.BUTTON)
    .accessibilityText(this.selected ?
      `${this.item.subject}，${this.item.title}，当前编辑` :
      `${this.item.subject}，${this.item.title}，打开编辑`)
    .onClick(() => this.onSelect());
  }
}

@Component
export struct ConfirmationCandidateEditor {
  @Prop item: CandidateAssignment;
  @Prop attachments: PendingAssignmentAttachment[] = [];
  @State private subjectDraft: Subject = Subject.CHINESE;
  @State private titleDraft: string = '';
  @State private instructionDraft: string = '';
  @State private taskDateDraft: string = '';
  @State private expectedMinutesDraft: number = 20;
  @State private textbookRefDraft: string = '';
  @State private attachmentDraft: PendingAssignmentAttachment[] = [];
  @State private confirmDiscard: boolean = false;
  @State private confirmDelete: boolean = false;
  @State private showFeedbackPanel: boolean = false;
  @State private feedbackTypes: HomeworkFeedbackType[] = [];
  @State private feedbackLoading: boolean = false;
  @State private feedbackSubmitting: boolean = false;
  @State private feedbackSelectedCode: string = '';
  @State private feedbackDetails: string = '';
  @State private feedbackMessage: string = '';
  @State private feedbackHasError: boolean = false;
  @State private showSavedExperiences: boolean = false;
  @State private loadingExperiences: boolean = false;
  @State private savedExperiences: HomeworkTeacherExperienceSummary[] = [];
  private feedbackRequestId: string = '';

  onClose: () => void = () => {};
  onSave: (candidate: CandidateAssignment, attachments: PendingAssignmentAttachment[]) => boolean =
    (_candidate: CandidateAssignment, _attachments: PendingAssignmentAttachment[]) => false;
  onDelete: (candidateId: string) => void = (_candidateId: string) => {};

  aboutToAppear(): void {
    this.subjectDraft = this.item.subject;
    this.titleDraft = this.item.title;
    this.instructionDraft = this.item.instruction;
    this.taskDateDraft = this.item.taskDate;
    this.expectedMinutesDraft = this.item.expectedMinutes;
    this.textbookRefDraft = this.item.textbookRef;
    this.attachmentDraft = this.attachments.slice();
    this.confirmDiscard = false;
    this.confirmDelete = false;
    this.showFeedbackPanel = false;
    this.feedbackSelectedCode = '';
    this.feedbackDetails = '';
    this.feedbackMessage = '';
    this.feedbackHasError = false;
    this.showSavedExperiences = false;
    this.savedExperiences = [];
    this.feedbackRequestId = '';
  }

  private toggleFeedbackPanel(): void {
    this.showFeedbackPanel = !this.showFeedbackPanel;
    if (this.showFeedbackPanel && this.feedbackTypes.length === 0) {
      void this.loadFeedbackTypes();
    }
  }

  private async loadFeedbackTypes(): Promise<void> {
    if (this.feedbackLoading) return;
    this.feedbackLoading = true;
    this.feedbackMessage = '';
    try {
      this.feedbackTypes = await HomeworkOrganizerFeedbackRemoteApi.instance.listTypes(this.item.studentId);
    } catch {
      this.feedbackHasError = true;
      this.feedbackMessage = '反馈选项加载失败，请检查网络后重试';
    } finally {
      this.feedbackLoading = false;
    }
  }

  private async toggleSavedExperiences(): Promise<void> {
    this.showSavedExperiences = !this.showSavedExperiences;
    if (!this.showSavedExperiences) return;
    this.loadingExperiences = true;
    try {
      this.savedExperiences = await HomeworkOrganizerFeedbackRemoteApi.instance
        .listExperiences(this.item.studentId);
    } catch {
      this.feedbackHasError = true;
      this.feedbackMessage = '作业经验列表加载失败';
    } finally {
      this.loadingExperiences = false;
    }
  }

  private async setSavedExperienceActive(item: HomeworkTeacherExperienceSummary): Promise<void> {
    try {
      let updated = await HomeworkOrganizerFeedbackRemoteApi.instance
        .setExperienceActive(this.item.studentId, item.id, !item.active);
      this.savedExperiences = this.savedExperiences.map((old: HomeworkTeacherExperienceSummary) =>
        old.id === updated.id ? updated : old);
      this.feedbackHasError = false;
      this.feedbackMessage = updated.active ? '已重新启用这条作业经验' : '已停用，后续整理不再引用这条经验';
    } catch {
      this.feedbackHasError = true;
      this.feedbackMessage = '经验状态更新失败，请重试';
    }
  }

  private selectedFeedbackType(): HomeworkFeedbackType | null {
    for (let option of this.feedbackTypes) {
      if (option.code === this.feedbackSelectedCode) return option;
    }
    return null;
  }

  private async submitFeedback(): Promise<void> {
    if (this.feedbackSubmitting) return;
    let type = this.selectedFeedbackType();
    if (type === null) {
      this.feedbackHasError = true;
      this.feedbackMessage = '请选择要反馈的问题';
      return;
    }
    if (type.requiresComment && this.feedbackDetails.trim().length === 0) {
      this.feedbackHasError = true;
      this.feedbackMessage = '请简要说明具体问题或正确写法';
      return;
    }
    if (this.feedbackRequestId.length === 0) {
      this.feedbackRequestId = `${this.item.id}-${Date.now()}-${Math.floor(Math.random() * 100000)}`;
    }
    let evidence = this.item.sourceEvidence;
    let input: HomeworkFeedbackInput = {
      clientRequestId: this.feedbackRequestId.substring(0, 160),
      candidateId: this.item.id.substring(0, 180),
      batchId: evidence.batchId === undefined ? '' : evidence.batchId.substring(0, 180),
      teacherName: evidence.teacherName === undefined ? '' : evidence.teacherName.substring(0, 80),
      subject: this.item.subject,
      feedbackTypeCode: type.code,
      sourceLabel: evidence.sourceLabel.substring(0, 200),
      sourceExcerpt: evidence.excerpt.substring(0, 500),
      originalTitle: HomeworkOrganizerRemoteApi.instance.originalTitle(
        this.item.id, this.item.title).substring(0, 400),
      currentTitle: this.item.title.substring(0, 400),
      details: this.feedbackDetails.trim().substring(0, 1200)
    };
    this.feedbackSubmitting = true;
    this.feedbackMessage = '';
    try {
      let receipt = await HomeworkOrganizerFeedbackRemoteApi.instance.submit(this.item.studentId, input);
      this.feedbackHasError = false;
      this.feedbackMessage = receipt.processingStatus === 'APPLIED'
        ? '反馈已保存，已自动形成当前学生的作业经验，下次匹配时生效'
        : (receipt.processingStatus === 'REVIEW_REQUIRED'
          ? '反馈已保存；同类经验存在冲突，暂不自动启用'
          : '反馈已保存；缺少足够原始证据，暂未生成新经验');
      this.showFeedbackPanel = false;
      this.feedbackSelectedCode = '';
      this.feedbackDetails = '';
      this.feedbackRequestId = '';
      if (receipt.processingStatus === 'APPLIED' && this.showSavedExperiences) {
        try {
          this.savedExperiences = await HomeworkOrganizerFeedbackRemoteApi.instance
            .listExperiences(this.item.studentId);
        } catch {
          // The feedback and the rule were already committed. A list refresh
          // failure must not present the saved feedback as failed.
        }
      }
    } catch {
      this.feedbackHasError = true;
      this.feedbackMessage = '反馈保存失败，内容已保留，请重试';
    } finally {
      this.feedbackSubmitting = false;
    }
  }

  private originalEditValues(): AssignmentEditValues {
    return {
      subject: this.item.subject,
      title: this.item.title,
      instruction: this.item.instruction,
      taskDate: this.item.taskDate,
      expectedMinutes: this.item.expectedMinutes,
      textbookRef: this.item.textbookRef
    };
  }

  private currentEditValues(): AssignmentEditValues {
    return {
      subject: this.subjectDraft,
      title: this.titleDraft,
      instruction: this.instructionDraft,
      taskDate: this.taskDateDraft,
      expectedMinutes: this.expectedMinutesDraft,
      textbookRef: this.textbookRefDraft
    };
  }

  private attachmentsChanged(): boolean {
    if (this.attachments.length !== this.attachmentDraft.length) return true;
    for (let i = 0; i < this.attachments.length; i++) {
      let original = this.attachments[i];
      let draft = this.attachmentDraft[i];
      if (original.resourceType !== draft.resourceType || original.uri !== draft.uri ||
        original.displayName !== draft.displayName) return true;
    }
    return false;
  }

  private hasChanges(): boolean {
    return AssignmentEditChangeDetector.hasChanges(this.originalEditValues(), this.currentEditValues()) ||
      this.attachmentsChanged();
  }

  private markChanged(): void {
    this.confirmDiscard = false;
    this.confirmDelete = false;
  }

  private buildCandidate(): CandidateAssignment {
    return {
      id: this.item.id,
      studentId: this.item.studentId,
      subject: this.subjectDraft,
      title: this.titleDraft,
      instruction: this.instructionDraft,
      textbookRef: this.textbookRefDraft,
      taskDate: this.taskDateDraft,
      expectedMinutes: this.expectedMinutesDraft,
      sourceEvidence: {
        sourceLabel: this.item.sourceEvidence.sourceLabel,
        excerpt: this.item.sourceEvidence.excerpt,
        teacherName: this.item.sourceEvidence.teacherName,
        batchId: this.item.sourceEvidence.batchId,
        sourceType: this.item.sourceEvidence.sourceType,
        sourceMessageIds: this.item.sourceEvidence.sourceMessageIds === undefined ?
          undefined : this.item.sourceEvidence.sourceMessageIds.slice(),
        rawText: this.item.sourceEvidence.rawText,
        imageRef: this.item.sourceEvidence.imageRef,
        capturedAtEpochMs: this.item.sourceEvidence.capturedAtEpochMs
      },
      confidence: this.item.confidence
    };
  }

  private requestClose(): void {
    if (this.hasChanges()) {
      this.confirmDiscard = true;
      this.confirmDelete = false;
      return;
    }
    this.onClose();
  }

  private saveAndClose(): void {
    if (!this.onSave(this.buildCandidate(), this.attachmentDraft.slice())) return;
    this.onClose();
  }

  @Builder
  private BottomActions() {
    Column({ space: 8 }) {
      if (this.confirmDiscard) {
        Text('当前修改尚未完成，关闭将放弃这些修改。')
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.WARNING);
        Row({ space: 10 }) {
          Button('继续编辑', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(AppTheme.TEXT)
            .onClick(() => this.confirmDiscard = false);
          Button('放弃修改', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.DANGER_SOFT)
            .fontColor(AppTheme.DANGER)
            .onClick(() => {
              this.onClose();
            });
        }
        .width('100%');
      } else if (this.confirmDelete) {
        Text('删除后无法恢复，确定删除这项待确认作业？')
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.DANGER);
        Row({ space: 10 }) {
          Button('取消', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(AppTheme.TEXT)
            .onClick(() => this.confirmDelete = false);
          Button('确认删除', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.DANGER)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => this.onDelete(this.item.id));
        }
        .width('100%');
      } else {
        Row({ space: 10 }) {
          Button('删除', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.DANGER_SOFT)
            .fontColor(AppTheme.DANGER)
            .onClick(() => this.confirmDelete = true);
          Button('保存', { type: ButtonType.Normal })
            .layoutWeight(2)
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .onClick(() => this.saveAndClose());
        }
        .width('100%');
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 18 })
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: { top: 1 }, color: AppTheme.DIVIDER });
  }


  @Builder
  private FeedbackPanel() {
    Column({ space: 9 }) {
      Button(this.showFeedbackPanel ? '收起 AI 整理反馈' : '反馈 AI 整理问题',
        { type: ButtonType.Normal })
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .width('100%')
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_EMPHASIS)
        .fontColor(AppTheme.PRIMARY)
        .onClick(() => this.toggleFeedbackPanel());

      if (this.feedbackMessage.length > 0) {
        Text(this.feedbackMessage)
          .fontSize(AppTheme.META_SIZE)
          .fontColor(this.feedbackHasError ? AppTheme.DANGER : AppTheme.PRIMARY)
          .width('100%');
      }

      if (this.showFeedbackPanel) {
        if (this.feedbackLoading) {
          Text('正在加载可选反馈类型…')
            .fontSize(AppTheme.META_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        } else if (this.feedbackTypes.length === 0) {
          Button('重新加载反馈选项', { type: ButtonType.Normal })
            .onClick(() => { void this.loadFeedbackTypes(); });
        } else {
          Text('问题类型')
            .fontSize(AppTheme.LABEL_TITLE_SIZE)
            .fontColor(AppTheme.TEXT)
            .width('100%');

          Column({ space: 6 }) {
            ForEach(this.feedbackTypes, (option: HomeworkFeedbackType) => {
              Column({ space: 3 }) {
                ChoiceSelectionChip({
                  label: option.label,
                  selected: this.feedbackSelectedCode === option.code,
                  compact: true,
                  onSelect: () => {
                    this.feedbackSelectedCode = option.code;
                                    this.feedbackMessage = '';
                    this.feedbackRequestId = '';
                  }
                });
                if (this.feedbackSelectedCode === option.code && option.description.length > 0) {
                  Text(option.description)
                    .width('100%')
                    .fontSize(AppTheme.META_SIZE)
                    .fontColor(AppTheme.SUBTEXT);
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start);
            }, (option: HomeworkFeedbackType) => option.code);
          }
          .width('100%');

          TextArea({ text: this.feedbackDetails, placeholder: '请描述问题及正确做法，便于系统自动学习' })
            .width('100%')
            .height(100)
            .onChange((value: string) => {
              this.feedbackDetails = value;
              this.feedbackRequestId = '';
            });

          Text('提交后将自动尝试生成本学生的专属经验；证据不足或与已有规则冲突时不会误生效。')
            .fontSize(AppTheme.META_SIZE)
            .fontColor(AppTheme.SUBTEXT)
            .width('100%');

          Button(this.feedbackSubmitting ? '正在保存反馈…' : '提交反馈',
            { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .enabled(!this.feedbackSubmitting)
            .onClick(() => { void this.submitFeedback(); });
        }
      }

      Button(this.showSavedExperiences ? '收起已保存的作业经验' : '查看或停用作业经验',
        { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .backgroundColor(AppTheme.SURFACE_EMPHASIS)
        .fontColor(AppTheme.TEXT)
        .onClick(() => { void this.toggleSavedExperiences(); });

      if (this.showSavedExperiences) {
        if (this.loadingExperiences) {
          Text('正在加载作业经验…').fontColor(AppTheme.SUBTEXT);
        } else if (this.savedExperiences.length === 0) {
          Text('当前学生尚未积累作业经验').fontColor(AppTheme.SUBTEXT);
        } else {
          ForEach(this.savedExperiences, (experience: HomeworkTeacherExperienceSummary) => {
            Row({ space: 8 }) {
              Column({ space: 4 }) {
                Text(`${experience.teacherName.startsWith('学科归属:') ? '按科目' : experience.teacherName} · ${experience.subject} · ${experience.cue}`)
                  .fontSize(AppTheme.META_SIZE)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                Text(experience.interpretation)
                  .fontSize(AppTheme.META_SIZE)
                  .maxLines(2)
                  .fontColor(AppTheme.SUBTEXT);
              }
              .layoutWeight(1);
              Button(experience.active ? '停用' : '启用', { type: ButtonType.Normal })
                .fontSize(AppTheme.META_SIZE)
                .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
                .backgroundColor(AppTheme.SURFACE_EMPHASIS)
                .fontColor(AppTheme.PRIMARY)
                .onClick(() => { void this.setSavedExperienceActive(experience); });
            }
            .width('100%');
          }, (experience: HomeworkTeacherExperienceSummary) =>
            `${experience.id}-${experience.active}`);
        }
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING_COMPACT)
    .backgroundColor(AppTheme.SURFACE_SUBTLE)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column() {
      EditSheetHeader({
        title: '编辑作业',
        subtitle: `${this.item.subject} · ${this.item.title}`,
        closeAccessibilityText: '关闭编辑',
        onClose: () => this.requestClose()
      });

      Divider().color(AppTheme.DIVIDER);

      Scroll() {
        Column({ space: 12 }) {
          AssignmentEditForm({
            subject: this.subjectDraft,
            subjectEditable: true,
            title: this.titleDraft,
            instruction: this.instructionDraft,
            taskDate: this.taskDateDraft,
            expectedMinutes: this.expectedMinutesDraft,
            onSubjectChange: (subject: Subject) => {
              this.subjectDraft = subject;
              this.markChanged();
            },
            onTitleChange: (value: string) => {
              this.titleDraft = value;
              this.markChanged();
            },
            onInstructionChange: (value: string) => {
              this.instructionDraft = value;
              this.markChanged();
            },
            onTaskDateChange: (value: string) => {
              this.taskDateDraft = value;
              this.markChanged();
            },
            onMinutesChange: (minutes: number) => {
              this.expectedMinutesDraft = minutes;
              this.markChanged();
            }
          });

          PendingAssignmentAttachmentPicker({
            candidateId: this.item.id,
            attachments: this.attachmentDraft,
            onChange: (attachments: PendingAssignmentAttachment[]) => {
              this.attachmentDraft = attachments.slice();
              this.markChanged();
            }
          });

          Column({ space: 5 }) {
            Text(this.item.sourceEvidence.sourceLabel.length > 0 ?
              this.item.sourceEvidence.sourceLabel : '老师原文')
              .width('100%')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text(this.item.sourceEvidence.excerpt)
              .width('100%')
              .fontSize(13)
              .lineHeight(19)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%')
          .padding(AppTheme.CARD_PADDING_COMPACT)
          .backgroundColor(this.item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS);

          if (this.item.id.startsWith('ai-')) {
            this.FeedbackPanel();
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 16 });
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto);

      this.BottomActions();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.SURFACE);
  }
}
