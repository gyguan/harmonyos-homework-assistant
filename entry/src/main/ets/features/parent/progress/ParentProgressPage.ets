import { RemoteSubmission } from '../../../application/remote/RemoteSubmissionApi';
import { RemoteSubmissionCache } from '../../../application/remote/RemoteSubmissionCache';
import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, Submission } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct ParentProgressPage {
  @Prop sizeClass: WindowSizeClass;
  @Prop revision: number = 0;

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignments();
  }

  private submissions(assignmentId: string): Submission[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getSubmissionsForAssignment(assignmentId);
  }

  private remoteSubmissions(assignmentId: string): RemoteSubmission[] {
    let currentRevision = this.revision;
    return RemoteSubmissionCache.instance.get(assignmentId);
  }

  private timingText(item: Assignment): string {
    if (item.elapsedSeconds > 0 && item.status !== AssignmentStatus.IN_PROGRESS) {
      let actualMinutes = Math.max(1, Math.round(item.elapsedSeconds / 60));
      return `预计 ${item.expectedMinutes} 分钟 · 实际 ${actualMinutes} 分钟`;
    }
    if (item.status === AssignmentStatus.IN_PROGRESS && item.startedAtEpochMs > 0) {
      return `进行中 · 预计 ${item.expectedMinutes} 分钟`;
    }
    return `预计 ${item.expectedMinutes} 分钟`;
  }

  @Builder
  private LocalSubmission(submission: Submission) {
    Column({ space: 10 }) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(17).fontColor([AppTheme.SUCCESS]);
        Text(`已提交 · ${submission.fileLabel}`).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS);
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
    Column({ space: 6 }) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(17).fontColor([AppTheme.SUCCESS]);
        Text(`云端已提交 · ${submission.photos.length} 张照片`).fontSize(AppTheme.CAPTION_SIZE).fontWeight(FontWeight.Medium).fontColor(AppTheme.SUCCESS);
      }.width('100%');
      Text(submission.submittedAt.replace('T', ' ').substring(0, 16))
        .width('100%').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
      Text('照片保存在家庭云端；当前设备没有本地副本时，仅显示提交记录。')
        .width('100%').fontSize(12).fontColor(AppTheme.SUBTEXT);
    }.width('100%').padding(12).backgroundColor(AppTheme.SUCCESS_SOFT).borderRadius(AppTheme.CONTROL_RADIUS);
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
      if (this.submissions(item.id).length > 0) {
        this.LocalSubmission(this.submissions(item.id)[0]);
      } else if (this.remoteSubmissions(item.id).length > 0) {
        this.CloudSubmission(this.remoteSubmissions(item.id)[0]);
      }
    }.width('100%').padding(AppTheme.CARD_PADDING).backgroundColor(AppTheme.SURFACE).borderRadius(AppTheme.CARD_RADIUS);
  }

  build() {
    Scroll() {
      Column({ space: AppTheme.SECTION_GAP }) {
        Column({ space: 5 }) {
          Text('作业进度').fontSize(AppTheme.PAGE_TITLE_SIZE).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
          Text(`${HomeworkStore.instance.getStudent().name} · 今天做了什么、交了什么，一眼看到`).fontSize(13).fontColor(AppTheme.SUBTEXT);
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
