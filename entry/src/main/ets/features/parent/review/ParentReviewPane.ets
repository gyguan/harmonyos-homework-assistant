import {
  ParentSubmissionEvidence,
  ParentSubmissionEvidenceService
} from '../../../application/submission/ParentSubmissionEvidenceService';
import { AppTheme } from '../../../common/theme/AppTheme';
import { CloudSubmissionPhotoStrip } from '../../../components/submission/CloudSubmissionPhotoStrip';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';
import { ParentReviewViewModel } from './ParentReviewViewModel';

@Component
export struct ParentReviewPane {
  @Prop assignmentId: string = '';
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  @State private reviewNoteDraft: string = '';
  @State private operationNotice: string = '';
  @State private submitting: boolean = false;
  onReviewed: () => void = () => {};

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

  private actualMinutes(item: Assignment): number {
    if (item.elapsedSeconds <= 0) return 0;
    return Math.max(1, Math.round(item.elapsedSeconds / 60));
  }

  private async approve(): Promise<void> {
    if (this.submitting || this.assignment() === null) return;
    this.submitting = true;
    this.operationNotice = '';
    try {
      await this.viewModel.approve(this.assignmentId, this.reviewNoteDraft);
      this.reviewNoteDraft = '';
      this.operationNotice = '已通过验收';
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
      this.operationNotice = '已退回订正';
      this.localRevision++;
      this.onReviewed();
    } catch (error) {
      this.operationNotice = `${error}`;
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  private EmptyState() {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.doc_text')).fontSize(30).fontColor([AppTheme.TERTIARY_TEXT]);
      Text(this.assignmentId.length === 0 ? '选择一项作业查看验收详情' : '这项作业暂时找不到')
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Text('提交证据、实际用时和家长验收都会在这里显示。')
        .fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
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
            .backgroundColor(AppTheme.SURFACE_EMPHASIS);
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
          Text(this.evidence()!.submittedAtText).fontSize(11).fontColor(AppTheme.SUBTEXT);
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
        Button('退回订正', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.WARNING_SOFT)
          .fontColor(AppTheme.WARNING)
          .enabled(!this.submitting)
          .onClick(() => void this.returnForRework());
        Button(this.submitting ? '处理中…' : '通过', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .enabled(!this.submitting)
          .onClick(() => void this.approve());
      }
      .width('100%');
      if (this.operationNotice.length > 0) {
        Text(this.operationNotice).width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
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
    if (this.assignment() === null) {
      this.EmptyState();
    } else {
      Column({ space: 12 }) {
        Column({ space: 8 }) {
          Row() {
            Text(this.assignment()!.subject).fontSize(12).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY);
            Blank();
            Text(AssignmentStateMachine.label(this.assignment()!.status)).fontSize(12).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');
          Text(this.assignment()!.title).width('100%').fontSize(21).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Row({ space: 8 }) {
            Text(this.assignment()!.dueText.length > 0 ? this.assignment()!.dueText : '未设置截止时间')
              .fontSize(12).fontColor(AppTheme.SUBTEXT);
            Text('·').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
            Text(this.actualMinutes(this.assignment()!) > 0 ?
              `实际 ${this.actualMinutes(this.assignment()!)} 分钟` : `预计 ${this.assignment()!.expectedMinutes} 分钟`)
              .fontSize(12).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');
          if (this.assignment()!.reviewNote.length > 0 && this.assignment()!.status !== AssignmentStatus.SUBMITTED) {
            Text(`家长备注：${this.assignment()!.reviewNote}`)
              .width('100%').fontSize(12).lineHeight(18).fontColor(AppTheme.SUBTEXT);
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(15)
        .backgroundColor(AppTheme.SURFACE)
        .border({ width: 1, color: AppTheme.BORDER })
        .borderRadius(AppTheme.CONTROL_RADIUS);

        this.EvidenceSection();

        if (this.assignment()!.status === AssignmentStatus.SUBMITTED) {
          this.ReviewActions(this.assignment()!);
        } else {
          Text(this.assignment()!.status === AssignmentStatus.COMPLETED ? '这项作业已通过验收。' : '当前状态无需家长验收。')
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT)
            .padding(14)
            .backgroundColor(AppTheme.SURFACE_SUBTLE)
            .borderRadius(AppTheme.CONTROL_RADIUS);
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start);
    }
  }
}
