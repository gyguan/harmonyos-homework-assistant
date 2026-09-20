import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentEditForm } from '../../../components/assignment/AssignmentEditForm';
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

  onCancel: () => void = () => {};
  onSave: (assignment: Assignment) => void = (_assignment: Assignment) => {};

  aboutToAppear(): void {
    this.titleDraft = this.item.title;
    this.instructionDraft = this.item.instruction;
    this.textbookRefDraft = this.item.textbookRef;
    this.dueTextDraft = this.item.dueText;
    this.minutesDraft = `${this.item.expectedMinutes}`;
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

  private setMinutes(minutes: number): void {
    this.minutesDraft = `${minutes}`;
  }

  private buildAssignment(): Assignment {
    let dueText = this.dueTextDraft.trim();
    let dueAt = dueText.length === 0 ? 0 : AssignmentDueDate.resolveDueAtEpochMs(dueText);
    let dueDateKey = dueText.length === 0 ? '' : AssignmentDueDate.resolveDateKey(dueText);
    return {
      id: this.item.id,
      studentId: this.item.studentId,
      candidateId: this.item.candidateId,
      assignmentType: this.item.assignmentType,
      subjectCode: this.item.subjectCode,
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

  build() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('编辑任务')
            .fontSize(AppTheme.CARD_TITLE_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text(`${this.item.subject} · 不会修改作业状态和计时`)
            .fontSize(11)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        Text('取消')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT)
          .constraintSize({ minWidth: AppTheme.MIN_TOUCH_TARGET, minHeight: AppTheme.MIN_TOUCH_TARGET })
          .textAlign(TextAlign.Center)
          .accessibilityRole(AccessibilityRoleType.BUTTON)
          .onClick(() => this.onCancel());
      }
      .width('100%');

      AssignmentEditForm({
        subject: this.item.subject,
        subjectEditable: false,
        title: this.titleDraft,
        instruction: this.instructionDraft,
        dueText: this.dueTextDraft,
        expectedMinutes: this.parsedMinutes() > 0 ? this.parsedMinutes() : 20,
        textbookRef: this.textbookRefDraft,
        onTitleChange: (value: string) => this.titleDraft = value,
        onInstructionChange: (value: string) => this.instructionDraft = value,
        onDueTextChange: (value: string) => this.dueTextDraft = value,
        onMinutesChange: (minutes: number) => this.setMinutes(minutes),
        onTextbookRefChange: (value: string) => this.textbookRefDraft = value
      });

      Button(this.saving ? '保存中…' : '保存修改', { type: ButtonType.Normal })
        .width('100%')
        .height(AppTheme.BUTTON_HEIGHT)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .enabled(this.canSave())
        .backgroundColor(this.canSave() ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .onClick(() => this.onSave(this.buildAssignment()));
    }
    .width('100%');
  }
}
