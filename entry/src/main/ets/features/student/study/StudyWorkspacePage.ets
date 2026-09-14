import { HomeworkSubmissionService } from '../../../application/submission/HomeworkSubmissionService';
import { WindowSizeClass } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCard } from '../../../components/assignment/AssignmentCard';
import { HomeworkStore } from '../../../data/HomeworkStore';
import { Assignment, AssignmentStatus, Submission } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';

@Component
export struct StudyWorkspacePage {
  @Prop sizeClass: WindowSizeClass;
  @Prop tutorUnavailable: boolean = false;
  @Prop assignmentId: string = 'a-math-001';
  @Prop revision: number = 0;
  @State private compactTutorOpen: boolean = false;
  @State private submissionPhotoUris: string[] = [];
  @State private selectingPhotos: boolean = false;
  @State private submissionMessage: string = '';
  onBack: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private assignment(): Assignment | null {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getAssignment(this.assignmentId);
  }

  private assignments(): Assignment[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getTodayAssignments();
  }

  private submissions(): Submission[] {
    let currentRevision = this.revision;
    return HomeworkStore.instance.getSubmissionsForAssignment(this.assignmentId);
  }

  private primaryActionLabel(): string {
    let assignment = this.assignment();
    if (assignment === null) {
      return '作业不存在';
    }
    switch (assignment.status) {
      case AssignmentStatus.NOT_STARTED:
      case AssignmentStatus.OVERDUE:
      case AssignmentStatus.NEEDS_REWORK:
        return '开始作业';
      case AssignmentStatus.IN_PROGRESS:
        return '我做完了，准备提交';
      case AssignmentStatus.READY_TO_SUBMIT:
        if (this.selectingPhotos) {
          return '正在打开相册…';
        }
        return this.submissionPhotoUris.length === 0 ? '选择作业照片' : `确认提交 ${this.submissionPhotoUris.length} 张照片`;
      case AssignmentStatus.SUBMITTED:
        return '已提交';
      case AssignmentStatus.COMPLETED:
        return '已完成';
      default:
        return '继续';
    }
  }

  private primaryActionEnabled(): boolean {
    let assignment = this.assignment();
    if (assignment === null || this.selectingPhotos) {
      return false;
    }
    return assignment.status !== AssignmentStatus.SUBMITTED && assignment.status !== AssignmentStatus.COMPLETED;
  }

  private runPrimaryAction(): void {
    let assignment = this.assignment();
    if (assignment === null) {
      return;
    }
    let changed: boolean = false;
    if (assignment.status === AssignmentStatus.NOT_STARTED ||
      assignment.status === AssignmentStatus.OVERDUE ||
      assignment.status === AssignmentStatus.NEEDS_REWORK) {
      changed = HomeworkStore.instance.startAssignment(assignment.id);
    } else if (assignment.status === AssignmentStatus.IN_PROGRESS) {
      changed = HomeworkStore.instance.markReadyToSubmit(assignment.id);
    } else if (assignment.status === AssignmentStatus.READY_TO_SUBMIT) {
      if (this.submissionPhotoUris.length === 0) {
        void this.selectSubmissionPhotos();
        return;
      }
      changed = HomeworkSubmissionService.instance.submit(assignment.id, this.submissionPhotoUris);
      if (changed) {
        this.submissionPhotoUris = [];
        this.submissionMessage = '作业照片已提交';
      }
    }
    if (changed) {
      this.onStoreChanged();
    }
  }

  private async selectSubmissionPhotos(): Promise<void> {
    if (this.selectingPhotos) {
      return;
    }
    this.selectingPhotos = true;
    this.submissionMessage = '';
    let selected = await HomeworkSubmissionService.instance.selectPhotos();
    this.selectingPhotos = false;
    if (selected.length === 0) {
      this.submissionMessage = '未选择照片，原有选择保持不变';
      return;
    }
    this.submissionPhotoUris = selected;
    this.submissionMessage = `已选择 ${selected.length} 张，请确认后提交`;
  }

  private removeSubmissionPhoto(uri: string): void {
    let next: string[] = [];
    for (let item of this.submissionPhotoUris) {
      if (item !== uri) {
        next.push(item);
      }
    }
    this.submissionPhotoUris = next;
    this.submissionMessage = next.length === 0 ? '请重新选择作业照片' : `已选择 ${next.length} 张，请确认后提交`;
  }

  @Builder
  private PhotoStrip(photoUris: string[], removable: boolean) {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(photoUris, (uri: string) => {
          Column({ space: 5 }) {
            Image(uri)
              .width(96)
              .height(96)
              .objectFit(ImageFit.Cover)
              .borderRadius(10)
              .backgroundColor('#F1F3F5');
            if (removable) {
              Text('移除')
                .fontSize(11)
                .fontColor(AppTheme.DANGER)
                .onClick(() => this.removeSubmissionPhoto(uri));
            }
          }
          .width(96);
        }, (uri: string) => uri);
      }
      .padding({ right: 4 });
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off);
  }

  @Builder
  private SubmissionDraftPane() {
    if (this.assignment() !== null && this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT) {
      Column({ space: 10 }) {
        Row() {
          Text('提交作业照片').fontSize(16).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          Blank();
          Text('最多 6 张').fontSize(12).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');

        if (this.submissionPhotoUris.length > 0) {
          this.PhotoStrip(this.submissionPhotoUris, true);
          Text('请确认照片清晰、完整，页数和顺序无误。')
            .width('100%')
            .fontSize(12)
            .fontColor(AppTheme.SUBTEXT);
          Button('重新选择照片')
            .width('100%')
            .height(38)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => { void this.selectSubmissionPhotos(); });
        } else {
          Text('从系统相册选择已经拍好的作业照片，选择后可以预览再提交。')
            .width('100%')
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }

        if (this.submissionMessage.length > 0) {
          Text(this.submissionMessage)
            .width('100%')
            .fontSize(12)
            .fontColor(AppTheme.PRIMARY);
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#F7F8FA')
      .borderRadius(14);
    }
  }

  @Builder
  private SavedSubmissionPane() {
    if (this.submissions().length > 0) {
      let submission = this.submissions()[0];
      Column({ space: 8 }) {
        Text(`已提交：${submission.fileLabel} · ${submission.submittedAtText}`)
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUCCESS);
        this.PhotoStrip(submission.photoUris, false);
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#EEF9F3')
      .borderRadius(12);
    }
  }

  @Builder
  private TaskRail() {
    Column({ space: 10 }) {
      Text('今天').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
      ForEach(this.assignments(), (item: Assignment) => {
        AssignmentCard({ assignment: item });
      }, (item: Assignment) => item.id);
    }
    .width('100%');
  }

  @Builder
  private StudyContent() {
    if (this.assignment() === null) {
      Column({ space: 10 }) {
        Text('找不到这项作业').fontSize(20).fontWeight(FontWeight.Bold).fontColor(AppTheme.TEXT);
        Text('请返回今日作业重新进入。').fontSize(14).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(18);
    } else {
      Scroll() {
        Column({ space: 14 }) {
          Row() {
            Text(`${this.assignment()!.subject} · ${AssignmentStateMachine.label(this.assignment()!.status)}`)
              .fontSize(13)
              .fontColor(AppTheme.PRIMARY);
            Blank();
            Text(this.assignment()!.dueText).fontSize(12).fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');

          Text(this.assignment()!.title)
            .width('100%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
          Text(this.assignment()!.instruction)
            .width('100%')
            .fontSize(15)
            .fontColor(AppTheme.SUBTEXT);

          Column({ space: 8 }) {
            if (this.assignment()!.resourceLabels.length === 0) {
              Text('暂无老师附件').width('100%').fontSize(14).fontColor(AppTheme.SUBTEXT);
            } else {
              ForEach(this.assignment()!.resourceLabels, (label: string) => {
                Text(label).width('100%').fontSize(15);
              }, (label: string) => label);
            }
            Text('📘 ' + this.assignment()!.textbookRef)
              .width('100%')
              .fontSize(14)
              .fontColor(AppTheme.PRIMARY);
          }
          .width('100%')
          .padding(18)
          .borderRadius(16)
          .backgroundColor('#F4F6F9');

          this.SubmissionDraftPane();
          this.SavedSubmissionPane();

          Button(this.primaryActionLabel())
            .width('100%')
            .height(48)
            .enabled(this.primaryActionEnabled())
            .backgroundColor(this.primaryActionEnabled() ? AppTheme.PRIMARY : '#C9D1DD')
            .onClick(() => this.runPrimaryAction());
        }
        .width('100%');
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private TutorPane() {
    Column({ space: 12 }) {
      Text('问小伴')
        .width('100%')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT);

      if (this.tutorUnavailable) {
        Text('AI 辅导暂时不可用')
          .width('100%')
          .padding(14)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.WARNING)
          .backgroundColor('#FFF8E7')
          .borderRadius(14);
        Text('你仍然可以查看老师资料、完成作业并提交。联网或服务恢复后再继续问小伴。')
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
      } else {
        Text('你现在卡在哪一道题？可以拍给我看，也可以直接说。')
          .width('100%')
          .padding(14)
          .fontSize(14)
          .fontColor(AppTheme.TEXT)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .borderRadius(14);
        Text('提示策略：先给一点提示，不直接说答案。')
          .width('100%')
          .fontSize(12)
          .fontColor(AppTheme.SUBTEXT);
        TextInput({ placeholder: '输入问题…' })
          .width('100%')
          .height(44)
          .backgroundColor('#F7F8FA');
        Row({ space: 8 }) {
          Button('🎙 语音').layoutWeight(1);
          Button('📷 拍题').layoutWeight(1);
        }
        .width('100%');
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(18)
    .border({ width: 1, color: AppTheme.BORDER });
  }

  @Builder
  private CompactWorkspace() {
    if (this.compactTutorOpen) {
      Column({ space: 12 }) {
        Text('‹ 返回作业')
          .width('100%')
          .fontSize(14)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.compactTutorOpen = false);
        this.TutorPane();
      }
      .width('100%')
      .layoutWeight(1);
    } else {
      Column({ space: 12 }) {
        Column() {
          this.StudyContent();
        }
        .width('100%')
        .layoutWeight(1);

        Button('问小伴')
          .width('100%')
          .height(48)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.compactTutorOpen = true);
      }
      .width('100%')
      .layoutWeight(1);
    }
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('‹ 返回')
          .fontSize(15)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.onBack());
        Blank();
        if (this.assignment() !== null) {
          Text(this.assignment()!.dueText).fontSize(13).fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.sizeClass === WindowSizeClass.EXPANDED) {
        Row({ space: 14 }) {
          Column() { this.TaskRail(); }.width('20%');
          Column() { this.StudyContent(); }.width('50%').height('100%');
          Column() { this.TutorPane(); }.layoutWeight(1);
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top);
      } else if (this.sizeClass === WindowSizeClass.MEDIUM) {
        Row({ space: 14 }) {
          Column() { this.StudyContent(); }.width('64%').height('100%');
          Column() { this.TutorPane(); }.layoutWeight(1);
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top);
      } else {
        this.CompactWorkspace();
      }
    }
    .width('100%')
    .height('100%')
    .padding(18)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
