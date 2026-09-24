import { AssignmentEditChangeDetector, AssignmentEditValues } from '../../../common/state/AssignmentEditChangeDetector';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentEditForm } from '../../../components/assignment/AssignmentEditForm';
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
        Text(this.item.dueText)
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
    .borderRadius(AppTheme.PHONE_CARD_RADIUS)
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
  @State private subjectDraft: Subject = Subject.CHINESE;
  @State private titleDraft: string = '';
  @State private instructionDraft: string = '';
  @State private dueTextDraft: string = '';
  @State private expectedMinutesDraft: number = 20;
  @State private textbookRefDraft: string = '';
  @State private confirmDiscard: boolean = false;
  @State private confirmDelete: boolean = false;

  onClose: () => void = () => {};
  onSave: (candidate: CandidateAssignment) => boolean = (_candidate: CandidateAssignment) => false;
  onDelete: (candidateId: string) => void = (_candidateId: string) => {};

  aboutToAppear(): void {
    this.subjectDraft = this.item.subject;
    this.titleDraft = this.item.title;
    this.instructionDraft = this.item.instruction;
    this.dueTextDraft = this.item.dueText;
    this.expectedMinutesDraft = this.item.expectedMinutes;
    this.textbookRefDraft = this.item.textbookRef;
    this.confirmDiscard = false;
    this.confirmDelete = false;
  }

  private originalEditValues(): AssignmentEditValues {
    return {
      subject: this.item.subject,
      title: this.item.title,
      instruction: this.item.instruction,
      dueText: this.item.dueText,
      expectedMinutes: this.item.expectedMinutes,
      textbookRef: this.item.textbookRef
    };
  }

  private currentEditValues(): AssignmentEditValues {
    return {
      subject: this.subjectDraft,
      title: this.titleDraft,
      instruction: this.instructionDraft,
      dueText: this.dueTextDraft,
      expectedMinutes: this.expectedMinutesDraft,
      textbookRef: this.textbookRefDraft
    };
  }

  private hasChanges(): boolean {
    return AssignmentEditChangeDetector.hasChanges(this.originalEditValues(), this.currentEditValues());
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
      dueText: this.dueTextDraft,
      expectedMinutes: this.expectedMinutesDraft,
      sourceEvidence: {
        sourceLabel: this.item.sourceEvidence.sourceLabel,
        excerpt: this.item.sourceEvidence.excerpt,
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
    if (!this.onSave(this.buildCandidate())) return;
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
            dueText: this.dueTextDraft,
            expectedMinutes: this.expectedMinutesDraft,
            textbookRef: this.textbookRefDraft,
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
            onDueTextChange: (value: string) => {
              this.dueTextDraft = value;
              this.markChanged();
            },
            onMinutesChange: (minutes: number) => {
              this.expectedMinutesDraft = minutes;
              this.markChanged();
            },
            onTextbookRefChange: (value: string) => {
              this.textbookRefDraft = value;
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
          .padding(13)
          .backgroundColor(this.item.confidence < 0.8 ? AppTheme.WARNING_SOFT : AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS);
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
