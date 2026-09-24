import {
  ParentSubmissionEvidence,
  ParentSubmissionEvidenceService
} from '../../../application/submission/ParentSubmissionEvidenceService';
import { AppTheme } from '../../../common/theme/AppTheme';
import { ActionButton, ActionButtonKind, ActionButtonSize, TextAction, TextActionKind } from '../../../components/action/ActionControls';
import { CloudSubmissionPhotoStrip } from '../../../components/submission/CloudSubmissionPhotoStrip';
import { PhotoPreviewDialog } from '../../../components/submission/PhotoPreviewDialog';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';
import { ParentReviewViewModel } from './ParentReviewViewModel';
import { ParentAssignmentEditPanel } from './ParentAssignmentEditPanel';

@Component
export struct ParentReviewPane {
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  @State private reviewNoteDraft: string = '';
  @State private operationNotice: string = '';
  @State private submitting: boolean = false;
  @State private editingAssignmentId: string = '';
  @State private showEditSheet: boolean = false;
  @State private editSaving: boolean = false;
  @State private editNotice: string = '';
  @State private previewUri: string = '';
  @State private deleteConfirm: boolean = false;
  @State private deleteBusy: boolean = false;

  private previewController: CustomDialogController = new CustomDialogController({
    builder: PhotoPreviewDialog({ uri: $previewUri }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });
  onReviewed: () => void = () => {};
  onDeleted: () => void = () => {};

  private readonly viewModel: ParentReviewViewModel =
    new ParentReviewViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void {
    void this.refreshEvidence();
  }

  private assignment(): Assignment | null {
    let currentRevision = this.revision + this.localRevision;
    if (currentRevision < 0 || this.assignmentId.length === 0) return null;
    return this.viewModel.assignment(this.assignmentId);
  }

  private evidence(): ParentSubmissionEvidence | null {
    let currentRevision = this.revision + this.localRevision;
    if (currentRevision < 0 || this.assignmentId.length === 0) return null;
    return ParentSubmissionEvidenceService.instance.cachedLatest(this.assignmentId);
  }

  private async refreshEvidence(): Promise<void> {
    if (this.assignmentId.length === 0) return;
    await ParentSubmissionEvidenceService.instance.refreshLatest(this.assignmentId);
    this.localRevision++;
  }

  private openPreview(uri: string): void {
    if (uri.length === 0) return;
    this.previewUri = uri;
    this.previewController.open();
  }

  private actualMinutes(item: Assignment): number {
    if (item.elapsedSeconds <= 0) return 0;
    return Math.max(1, Math.round(item.elapsedSeconds / 60));
  }

  private canEdit(item: Assignment): boolean {
    return item.status !== AssignmentStatus.SUBMITTED && item.status !== AssignmentStatus.COMPLETED;
  }

  private canDelete(item: Assignment): boolean {
    return item.status !== AssignmentStatus.COMPLETED;
  }

  private async deleteAssignment(): Promise<void> {
    let item = this.assignment();
    if (item === null || !this.canDelete(item) || this.deleteBusy) return;
    this.deleteBusy = true;
    this.operationNotice = '';
    try {
      await this.viewModel.deleteAssignment(item.id);
      this.deleteConfirm = false;
      this.localRevision++;
      this.onDeleted();
    } catch (error) {
      this.operationNotice = `${error}`;
    } finally {
      this.deleteBusy = false;
    }
  }

  @Builder
  private DeleteConfirmation() {
    if (this.deleteConfirm && this.assignment() !== null && this.canDelete(this.assignment()!)) {
      Column({ space: 10 }) {
        Text('删除后无法恢复，确定删除这项未完成作业？')
          .width('100%')
          .fontSize(13)
          .lineHeight(19)
          .fontColor(AppTheme.DANGER);
        Row({ space: 10 }) {
          ActionButton({
            label: '取消',
            kind: ActionButtonKind.NEUTRAL,
            size: ActionButtonSize.SMALL,
            isEnabled: !this.deleteBusy,
            onAction: (): void => { this.deleteConfirm = false; }
          })
          .layoutWeight(1);
          ActionButton({
            label: this.deleteBusy ? '正在删除…' : '确认删除',
            kind: ActionButtonKind.DANGER,
            size: ActionButtonSize.SMALL,
            isEnabled: !this.deleteBusy,
            onAction: (): void => { void this.deleteAssignment(); }
          })
          .layoutWeight(1);
        }
        .width('100%');
      }
      .width('100%')
      .padding(12)
      .backgroundColor(AppTheme.DANGER_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  private startEditing(item: Assignment): void {
    if (!this.canEdit(item)) return;
    this.editingAssignmentId = item.id;
    this.editNotice = '';
    this.showEditSheet = true;
  }

  private cancelEditing(): void {
    this.showEditSheet = false;
    this.editNotice = '';
  }

  private completeEditingDismiss(): void {
    this.editingAssignmentId = '';
    this.editNotice = '';
  }

  private async saveAssignmentEdit(updated: Assignment): Promise<void> {
    if (this.editSaving || this.assignment() === null) return;
    this.editSaving = true;
    this.editNotice = '';
    try {
      await this.viewModel.updateDetails(updated);
      this.showEditSheet = false;
      this.editNotice = '';
      this.localRevision++;
      this.onReviewed();
    } catch (error) {
      this.editNotice = `${error}`;
    } finally {
      this.editSaving = false;
    }
  }

  private async approve(): Promise<void> {
    if (this.submitting || this.assignment() === null) return;
    this.submitting = true;
    this.operationNotice = '';
    try {
      await this.viewModel.approve(this.assignmentId, this.reviewNoteDraft);
      this.reviewNoteDraft = '';
      this.localRevision++;
      this.onReviewed();
    } catch (error) {
      this.operationNotice = `${error}`;
    } finally {
      this.submitting = false;
    }
  }

  private async returnForRework(): Promise<void> {
    if (this.submitting || this.assignment() === null) return;
    let note = this.reviewNoteDraft.trim();
    if (note.length === 0) {
      this.operationNotice = '退回订正时请填写原因';
      return;
    }
    this.submitting = true;
    this.operationNotice = '';
    try {
      await this.viewModel.returnForRework(this.assignmentId, note);
      this.reviewNoteDraft = '';
      this.localRevision++;
      this.onReviewed();
    } catch (error) {
      this.operationNotice = `${error}`;
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private AssignmentEditorSheet() {
    Column() {
      if (this.assignment() !== null && this.editingAssignmentId === this.assignment()!.id) {
        ParentAssignmentEditPanel({
          item: this.assignment()!,
          saving: this.editSaving,
          onCancel: () => this.cancelEditing(),
          onSave: (assignment: Assignment) => { void this.saveAssignmentEdit(assignment); }
        });
        if (this.editNotice.length > 0) {
          Text(this.editNotice)
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.DANGER)
            .padding({ left: 16, right: 16, bottom: 10 });
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.SURFACE);
  }

  @Builder
  private EmptyState() {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.doc_text')).fontSize(30).fontColor([AppTheme.TERTIARY_TEXT]);
      Text(this.assignmentId.length === 0 ? '选择一项作业查看详情' : '这项作业暂时找不到')
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 18, bottom: 24 });
  }

  @Builder
  private LocalPhotos(uris: string[]) {
    Scroll() {
      Row({ space: 9 }) {
        ForEach(uris, (uri: string) => {
          Image(uri)
            .width(86)
            .height(86)
            .objectFit(ImageFit.Cover)
            .borderRadius(12)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .accessibilityText('查看作业照片大图')
            .onClick(() => this.openPreview(uri));
        }, (uri: string) => uri);
      }
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off);
  }

  @Builder
  private EvidenceSection() {
    Column({ space: 10 }) {
      Row() {
        Text('提交证据').fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
        Blank();
        if (this.evidence() !== null) {
          Text(this.evidence()!.submittedAtText).fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.evidence() === null) {
        Text('暂未找到提交照片').width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT)
          .padding({ top: 12, bottom: 12 });
      } else if (this.evidence()!.remotePhotos.length > 0) {
        CloudSubmissionPhotoStrip({ photos: this.evidence()!.remotePhotos });
      } else if (this.evidence()!.localPhotoUris.length > 0) {
        this.LocalPhotos(this.evidence()!.localPhotoUris);
      } else {
        Text('本次提交没有可展示的照片').width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(15)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private ReviewActions(item: Assignment) {
    Column({ space: 10 }) {
      Text('家长验收').width('100%').fontSize(AppTheme.CARD_TITLE_SIZE)
        .fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      TextArea({ text: this.reviewNoteDraft, placeholder: '退回订正时填写原因；通过时可选填一句鼓励' })
        .width('100%')
        .height(88)
        .fontSize(14)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .borderRadius(AppTheme.CONTROL_RADIUS)
        .onChange((value: string) => this.reviewNoteDraft = value);
      Row({ space: 10 }) {
        ActionButton({
          label: '退回订正',
          kind: ActionButtonKind.WARNING,
          isEnabled: !this.submitting,
          onAction: (): void => void this.returnForRework()
        })
        .layoutWeight(1);
        ActionButton({
          label: this.submitting ? '处理中…' : '通过',
          isEnabled: !this.submitting,
          onAction: (): void => void this.approve()
        })
        .layoutWeight(1);
      }
      .width('100%');
      if (this.operationNotice.length > 0) {
        Text(this.operationNotice).width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(15)
    .backgroundColor(AppTheme.SURFACE)
    .border({ width: 1, color: AppTheme.BORDER })
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  build() {
    Column() {
        if (this.assignment() === null) {
          this.EmptyState();
        } else {
          Column({ space: 12 }) {
            Column({ space: 8 }) {
              Row() {
                Text(this.assignment()!.subject).fontSize(13).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
                Blank();
                Text(AssignmentStateMachine.label(this.assignment()!.status)).fontSize(13).fontColor(AppTheme.SUBTEXT);
              }
              .width('100%');
              Text(this.assignment()!.title).width('100%').fontSize(21).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
              Row({ space: 8 }) {
                Text(this.assignment()!.dueText.length > 0 ? this.assignment()!.dueText : '未设置截止时间')
                  .fontSize(13).fontColor(AppTheme.SUBTEXT);
                Text('·').fontSize(13).fontColor(AppTheme.TERTIARY_TEXT);
                Text(this.actualMinutes(this.assignment()!) > 0 ?
                  `实际 ${this.actualMinutes(this.assignment()!)} 分钟` : `预计 ${this.assignment()!.expectedMinutes} 分钟`)
                  .fontSize(13).fontColor(AppTheme.SUBTEXT);
              }
              .width('100%');

              if (this.canEdit(this.assignment()!) || this.canDelete(this.assignment()!)) {
                Row({ space: 6 }) {
                  if (this.canEdit(this.assignment()!)) {
                    TextAction({
                      label: '编辑',
                      accessibilityLabel: '编辑这项作业',
                      onAction: (): void => this.startEditing(this.assignment()!)
                    });
                  }
                  Blank();
                  if (this.canDelete(this.assignment()!)) {
                    TextAction({
                      label: '删除',
                      kind: TextActionKind.DANGER,
                      accessibilityLabel: '删除这项未完成作业',
                      onAction: (): void => { this.deleteConfirm = true; }
                    });
                  }
                }
                .width('100%');
              }
              if (this.assignment()!.reviewNote.length > 0 && this.assignment()!.status !== AssignmentStatus.SUBMITTED) {
                Text(`家长备注：${this.assignment()!.reviewNote}`)
                  .width('100%').fontSize(13).lineHeight(18).fontColor(AppTheme.SUBTEXT);
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(15)
            .backgroundColor(AppTheme.SURFACE)
            .border({ width: 1, color: AppTheme.BORDER })
            .borderRadius(AppTheme.CONTROL_RADIUS);

            this.DeleteConfirmation();

            if (this.operationNotice.length > 0 && this.assignment()!.status !== AssignmentStatus.SUBMITTED) {
              Text(this.operationNotice)
                .width('100%')
                .fontSize(13)
                .fontColor(AppTheme.SUCCESS)
                .padding({ left: 12, right: 12, top: 9, bottom: 9 })
                .backgroundColor(AppTheme.SUCCESS_SOFT)
                .borderRadius(AppTheme.CONTROL_RADIUS);
            }

            this.EvidenceSection();

            if (this.assignment()!.status === AssignmentStatus.SUBMITTED) {
              this.ReviewActions(this.assignment()!);
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);
        }

    }
    .width('100%')
    .bindSheet($$this.showEditSheet, this.AssignmentEditorSheet(), {
      height: '82%',
      showClose: false,
      preferType: SheetType.BOTTOM,
      onDisappear: () => this.completeEditingDismiss()
    });
  }
}
