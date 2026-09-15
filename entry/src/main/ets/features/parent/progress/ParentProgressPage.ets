import { HomeworkSyncService } from '../../../application/remote/HomeworkSyncService';
import { RemoteSubmission } from '../../../application/remote/RemoteSubmissionApi';
import { RemoteSubmissionCache } from '../../../application/remote/RemoteSubmissionCache';
import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { CloudSubmissionPhotoStrip } from '../../../components/submission/CloudSubmissionPhotoStrip';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, Submission } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct ParentProgressPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;
  @State private localRevision: number = 0;
  @State private reviewAssignmentId: string = '';
  @State private reviewNoteDraft: string = '';
  onStoreChanged: () => void = () => {};

  private assignments(): Assignment[] {
    let currentRevision = this.revision + this.localRevision;
    return HomeworkStore.instance.getAssignments();
  }

  private submissions(assignmentId: string): Submission[] {
    let currentRevision = this.revision + this.localRevision;
    return HomeworkStore.instance.getSubmissionsForAssignment(assignmentId);
  }

  private latestLocalSubmission(assignmentId: string): Submission | null {
    let items = this.submissions(assignmentId);
    return items.length === 0 ? null : items[items.length - 1];
  }

  private remoteSubmissions(assignmentId: string): RemoteSubmission[] {
    let currentRevision = this.revision + this.localRevision;
    return RemoteSubmissionCache.instance.get(assignmentId);
  }

  private timingText(item: Assignment): string {
    if (item.status === AssignmentStatus.PAUSED) {
      let usedMinutes = item.elapsedSeconds > 0 ? Math.max(1, Math.round(item.elapsedSeconds / 60)) : 0;
      return `已暂停 · 已用 ${usedMinutes} 分钟 / 预计 ${item.expectedMinutes} 分钟`;
    }
    if (item.elapsedSeconds > 0 && item.status !== AssignmentStatus.IN_PROGRESS) {
      let actualMinutes = Math.max(1, Math.round(item.elapsedSeconds / 60));
      return `预计 ${item.expectedMinutes} 分钟 · 实际 ${actualMinutes} 分钟`;
    }
    if (item.status === AssignmentStatus.IN_PROGRESS && item.startedAtEpochMs > 0) {
      return `进行中 · 预计 ${item.expectedMinutes} 分钟`;
    }
    return `预计 ${item.expectedMinutes} 分钟`;
  }

  private openReview(item: Assignment): void {
    this.reviewAssignmentId = item.id;
    this.reviewNoteDraft = item.reviewNote;
  }

  private closeReview(): void {
    this.reviewAssignmentId = '';
    this.reviewNoteDraft = '';
  }

  private submitReview(item: Assignment, completed: boolean): void {
    let note = this.reviewNoteDraft.trim();
    if (!completed && note.length === 0) return;
    if (HomeworkStore.instance.reviewAssignment(item.id, completed, note)) {
      this.closeReview();
      this.localRevision++;
      this.onStoreChanged();
      HomeworkSyncService.instance.requestSync();
    }
  }

  @Builder
  private LocalSubmission(submission: Submission) {
    Column({ space: 10 }) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(17).fontColor([AppTheme.SUCCESS]);
        Text(`最新提交 · ${submission.fileLabel}`).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS);
        Blank();
        Text(submission.submittedAtText).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      }.width('100%');
      Scroll() {
        Row({ space: 9 }) {
          ForEach(submission.photoUris, (uri: string) => {
            Image(uri).width(86).height(86).objectFit(ImageFit.Cover).borderRadius(12).backgroundColor(AppTheme.SURFACE_EMPHASIS);
          }, (uri: string) => uri);
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
    }.width('100%').padding(12).backgroundColor(AppTheme.SUCCESS_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private CloudSubmission(submission: RemoteSubmission) {
    Column({ space: 8 }) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(17).fontColor([AppTheme.SUCCESS]);
        Text(`云端已提交 · ${submission.photos.length} 张照片`).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS);
      }.width('100%');
      Text(submission.submittedAt.replace('T', ' ').substring(0, 16))
        .width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      CloudSubmissionPhotoStrip({ photos: submission.photos });
      Text('照片通过家庭账号鉴权加载，并缓存在当前设备。')
        .width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
    }.width('100%').padding(12).backgroundColor(AppTheme.SUCCESS_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private ReviewPane(item: Assignment) {
    if (item.status === AssignmentStatus.SUBMITTED) {
      if (this.reviewAssignmentId === item.id) {
        Column({ space: 10 }) {
          Text('家长验收').width('100%').fontSize(15).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          TextArea({ placeholder: '可写一句鼓励；如果需要订正，请告诉孩子具体改哪里。', text: this.reviewNoteDraft })
            .width('100%').height(86).backgroundColor(AppTheme.SURFACE_SUBTLE).borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.reviewNoteDraft = value.substring(0, 1000));
          Row({ space: 8 }) {
            Button('取消', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.SURFACE_EMPHASIS).fontColor(AppTheme.SUBTEXT)
              .onClick(() => this.closeReview());
            Button('需要订正', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).enabled(this.reviewNoteDraft.trim().length > 0)
              .backgroundColor(AppTheme.WARNING_SOFT).fontColor(AppTheme.WARNING)
              .onClick(() => this.submitReview(item, false));
            Button('确认完成', { type: ButtonType.Normal }).layoutWeight(1).height(AppTheme.SECONDARY_BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.PRIMARY).fontColor(AppTheme.TEXT_ON_PRIMARY)
              .onClick(() => this.submitReview(item, true));
          }.width('100%');
        }.width('100%').padding(13).backgroundColor(AppTheme.PRIMARY_FAINT).borderRadius(AppTheme.CONTROL_RADIUS);
      } else {
        Button('验收作业', { type: ButtonType.Normal }).width('100%').height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS).backgroundColor(AppTheme.PRIMARY_SOFT).fontColor(AppTheme.PRIMARY)
          .onClick(() => this.openReview(item));
      }
    } else if (item.reviewNote.length > 0 &&
      (item.status === AssignmentStatus.NEEDS_REWORK || item.status === AssignmentStatus.COMPLETED)) {
      Column({ space: 4 }) {
        Text(item.status === AssignmentStatus.NEEDS_REWORK ? '订正说明' : '家长留言')
          .width('100%').fontSize(12).fontWeight(FontWeight.Medium)
          .fontColor(item.status === AssignmentStatus.NEEDS_REWORK ? AppTheme.WARNING : AppTheme.SUCCESS);
        Text(item.reviewNote).width('100%').fontSize(13).lineHeight(19).fontColor(AppTheme.TEXT);
      }.width('100%').padding(12)
        .backgroundColor(item.status === AssignmentStatus.NEEDS_REWORK ? AppTheme.WARNING_SOFT : AppTheme.SUCCESS_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private ProgressCard(item: Assignment) {
    Column({ space: 11 }) {
      Row() {
        Text(item.subject).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.PRIMARY)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 }).backgroundColor(AppTheme.PRIMARY_SOFT).borderRadius(AppTheme.CHIP_RADIUS);
        Blank();
        Text(AssignmentStateMachine.label(item.status)).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUBTEXT);
      }.width('100%');
      Text(item.title).width('100%').fontSize(AppTheme.CARD_TITLE_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
      Row() {
        Text(`截至 ${item.dueText}`).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
        Blank();
        Text(this.timingText(item)).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.PRIMARY);
      }.width('100%');
      if (this.latestLocalSubmission(item.id) !== null) {
        this.LocalSubmission(this.latestLocalSubmission(item.id)!);
      } else if (this.remoteSubmissions(item.id).length > 0) {
        this.CloudSubmission(this.remoteSubmissions(item.id)[0]);
      }
      this.ReviewPane(item);
    }.width('100%').padding(AppTheme.CARD_PADDING).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CARD_RADIUS);
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text('作业进度').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(`${HomeworkStore.instance.getStudent().name} · 提交后由家长验收，完成或打回订正`).fontSize(13).fontColor(AppTheme.SUBTEXT);
        }.width('100%').alignItems(HorizontalAlign.Start);
        if (this.sizeClass === WindowSizeClass.EXPANDED) {
          Row({ space: 16 }) {
            Column({ space: AppTheme.ITEM_GAP }) {
              ForEach(this.assignments().slice(0, Math.ceil(this.assignments().length / 2)), (item: Assignment) => {
                this.ProgressCard(item);
              }, (item: Assignment) => item.id);
            }.layoutWeight(1);
            Column({ space: AppTheme.ITEM_GAP }) {
              ForEach(this.assignments().slice(Math.ceil(this.assignments().length / 2)), (item: Assignment) => {
                this.ProgressCard(item);
              }, (item: Assignment) => item.id);
            }.layoutWeight(1);
          }.width('100%').alignItems(VerticalAlign.Top);
        } else {
          ForEach(this.assignments(), (item: Assignment) => {
            this.ProgressCard(item);
          }, (item: Assignment) => item.id);
        }
      }.width('100%').padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING);
    }.width('100%').height('100%').backgroundColor(AppTheme.BACKGROUND);
  }
}
