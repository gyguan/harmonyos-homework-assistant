import { AssignmentEditChangeDetector, AssignmentEditValues } from '../../../common/state/AssignmentEditChangeDetector';
import { AppTheme } from '../../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind, ActionButtonSize } from '../../../components/action/ActionControls';
import { AssignmentEditForm } from '../../../components/assignment/AssignmentEditForm';
import { EditSheetHeader } from '../../../components/navigation/EditSheetHeader';
import { Assignment } from '../../../domain/model/HomeworkModels';
import { AssignmentDueDate } from '../../../domain/service/AssignmentDueDate';

@Component
export struct ParentAssignmentEditPanel {
  @Prop item: Assignment;
  @Prop saving: boolean = false;
  @State private titleDraft: string = '';
  @State private instructionDraft: string = '';
  @State private textbookRefDraft: string = '';
  @State private dueTextDraft: string = '';
  @State private minutesDraft: string = '20';
  @State private confirmDiscard: boolean = false;

  onCancel: () => void = () => {};
  onSave: (assignment: Assignment) => void = (_assignment: Assignment) => {};

  aboutToAppear(): void {
    this.titleDraft = this.item.title;
    this.instructionDraft = this.item.instruction;
    this.textbookRefDraft = this.item.textbookRef;
    this.dueTextDraft = this.item.dueText;
    this.minutesDraft = `${this.item.expectedMinutes}`;
    this.confirmDiscard = false;
  }

  private parsedMinutes(): number {
    let value = Math.round(Number(this.minutesDraft));
    if (!Number.isFinite(value)) return -1;
    return value;
  }

  private canSave(): boolean {
    let minutes = this.parsedMinutes();
    return !this.saving && this.titleDraft.trim().length > 0 && minutes >= 1 && minutes <= 240;
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
      subject: this.item.subject,
      title: this.titleDraft,
      instruction: this.instructionDraft,
      dueText: this.dueTextDraft,
      expectedMinutes: this.parsedMinutes(),
      textbookRef: this.textbookRefDraft
    };
  }

  private hasChanges(): boolean {
    return AssignmentEditChangeDetector.hasChanges(this.originalEditValues(), this.currentEditValues());
  }

  private markChanged(): void {
    this.confirmDiscard = false;
  }

  private setMinutes(minutes: number): void {
    this.minutesDraft = `${minutes}`;
    this.markChanged();
  }

  private requestClose(): void {
    if (this.hasChanges()) {
      this.confirmDiscard = true;
      return;
    }
    this.onCancel();
  }

  private buildAssignment(): Assignment {
    let dueText = this.dueTextDraft.trim();
    let dueAt = dueText.length === 0 ? 0 : AssignmentDueDate.resolveDueAtEpochMs(dueText);
    let dueDateKey = dueText.length === 0 ? '' : AssignmentDueDate.resolveDateKey(dueText);
    return {
      id: this.item.id,
      studentId: this.item.studentId,
      candidateId: this.item.candidateId,
      backing: this.item.backing,
      assignmentType: this.item.assignmentType,
      subjectCode: this.item.subjectCode,
      contentType: this.item.contentType,
      subject: this.item.subject,
      title: this.titleDraft.trim(),
      instruction: this.instructionDraft.trim(),
      textbookRef: this.textbookRefDraft.trim(),
      dueAtEpochMs: dueAt > 0 ? dueAt : 0,
      dueTimezone: this.item.dueTimezone,
      dueText: dueText,
      dueDateKey: dueDateKey,
      status: this.item.status,
      expectedMinutes: this.parsedMinutes(),
      startedAtEpochMs: this.item.startedAtEpochMs,
      finishedAtEpochMs: this.item.finishedAtEpochMs,
      elapsedSeconds: this.item.elapsedSeconds,
      reviewNote: this.item.reviewNote,
      remoteVersion: this.item.remoteVersion,
      syncDirty: false,
      lastSyncedAtEpochMs: this.item.lastSyncedAtEpochMs,
      resourceLabels: this.item.resourceLabels.slice()
    };
  }

  @Builder
  private BottomActions() {
    Column({ space: 8 }) {
      if (this.confirmDiscard) {
        Text('当前修改尚未保存，关闭将放弃这些修改。')
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.WARNING);
        Row({ space: 10 }) {
          ActionButton({
            label: '继续编辑',
            kind: ActionButtonKind.NEUTRAL,
            size: ActionButtonSize.SMALL,
            onAction: (): void => { this.confirmDiscard = false; }
          })
          .layoutWeight(1);
          ActionButton({
            label: '放弃修改',
            kind: ActionButtonKind.DANGER_SOFT,
            size: ActionButtonSize.SMALL,
            onAction: (): void => {
              this.onCancel();
            }
          })
          .layoutWeight(1);
        }
        .width('100%');
      } else {
        ActionButton({
          label: this.saving ? '保存中…' : '保存修改',
          isEnabled: this.canSave(),
          onAction: (): void => this.onSave(this.buildAssignment())
        })
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
        title: '编辑任务',
        subtitle: `${this.item.subject} · 不会修改作业状态和计时`,
        closeAccessibilityText: '关闭任务编辑',
        onClose: () => this.requestClose()
      });

      Divider().color(AppTheme.DIVIDER);

      Scroll() {
        AssignmentEditForm({
          subject: this.item.subject,
          subjectEditable: false,
          title: this.titleDraft,
          instruction: this.instructionDraft,
          dueText: this.dueTextDraft,
          expectedMinutes: this.parsedMinutes() > 0 ? this.parsedMinutes() : 20,
          textbookRef: this.textbookRefDraft,
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
          onMinutesChange: (minutes: number) => this.setMinutes(minutes),
          onTextbookRefChange: (value: string) => {
            this.textbookRefDraft = value;
            this.markChanged();
          }
        })
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
