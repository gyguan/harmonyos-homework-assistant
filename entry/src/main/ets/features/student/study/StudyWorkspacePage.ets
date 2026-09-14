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
  @State private submittingPhotos: boolean = false;
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
        if (this.submittingPhotos) {
          return '正在保存并提交…';
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
    if (assignment === null || this.selectingPhotos || this.submittingPhotos) {
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
      void this.submitSelectedPhotos(assignment.id);
      return;
    }
    if (changed) {
      this.onStoreChanged();
    }
  }

  private async selectSubmissionPhotos(): Promise<void> {
    if (this.selectingPhotos || this.submittingPhotos) {
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

  private async submitSelectedPhotos(assignmentId: string): Promise<void> {
    if (this.submittingPhotos || this.submissionPhotoUris.length === 0) {
      return;
    }
    this.submittingPhotos = true;
    this.submissionMessage = '正在把照片保存到本地…';
    try {
      let submitted = await HomeworkSubmissionService.instance.submit(assignmentId, this.submissionPhotoUris);
      if (!submitted) {
        this.submissionMessage = '提交失败，请确认作业状态后重试';
        return;
      }
      this.submissionPhotoUris = [];
      this.submissionMessage = '作业照片已提交';
      this.onStoreChanged();
    } catch {
      this.submissionMessage = '照片保存失败，请重新选择后再试';
    } finally {
      this.submittingPhotos = false;
    }
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
          Column({ space: 6 }) {
            Image(uri)
              .width(96)
              .height(96)
              .objectFit(ImageFit.Cover)
              .borderRadius(12)
              .backgroundColor(AppTheme.SURFACE_EMPHASIS);
            if (removable) {
              Text('移除')
                .fontSize(11)
                .fontColor(AppTheme.DANGER)
                .padding({ top: 2, bottom: 2 })
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
      Column({ space: 11 }) {
        Row() {
          Text('提交作业照片')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Blank();
          Text('最多 6 张').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');

        if (this.submissionPhotoUris.length > 0) {
          this.PhotoStrip(this.submissionPhotoUris, true);
          Text('请确认照片清晰、完整，页数和顺序无误。')
            .width('100%')
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.SUBTEXT);
          Button('重新选择照片', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.submittingPhotos)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => { void this.selectSubmissionPhotos(); });
        } else {
          Text('从系统相册选择已经拍好的作业照片，选择后可以预览再提交。')
            .width('100%')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(AppTheme.SUBTEXT);
        }

        if (this.submissionMessage.length > 0) {
          Text(this.submissionMessage)
            .width('100%')
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.PRIMARY);
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor(AppTheme.PRIMARY_FAINT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private SavedSubmissionPane() {
    if (this.submissions().length > 0) {
      Column({ space: 9 }) {
        Row({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(17)
            .fontColor([AppTheme.SUCCESS]);
          Text(`已提交 · ${this.submissions()[0].fileLabel}`)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.SUCCESS);
          Blank();
          Text(this.submissions()[0].submittedAtText)
            .fontSize(AppTheme.CAPTION_SIZE)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%');
        this.PhotoStrip(this.submissions()[0].photoUris, false);
      }
      .width('100%')
      .padding(13)
      .backgroundColor(AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private TaskRail() {
    Column({ space: AppTheme.ITEM_GAP }) {
      Text('今天的作业')
        .width('100%')
        .fontSize(AppTheme.SECTION_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
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
        Text('找不到这项作业')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('请返回今日作业重新进入。')
          .fontSize(AppTheme.BODY_SIZE)
          .fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .padding(AppTheme.CARD_PADDING)
      .backgroundColor(AppTheme.SURFACE)
      .borderRadius(AppTheme.CARD_RADIUS);
    } else {
      Scroll() {
        Column({ space: 15 }) {
          Row() {
            Text(this.assignment()!.subject)
              .fontSize(AppTheme.CAPTION_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.PRIMARY)
              .padding({ left: 9, right: 9, top: 5, bottom: 5 })
              .backgroundColor(AppTheme.PRIMARY_SOFT)
              .borderRadius(AppTheme.CHIP_RADIUS);
            Text(AssignmentStateMachine.label(this.assignment()!.status))
              .fontSize(AppTheme.CAPTION_SIZE)
              .fontColor(AppTheme.SUBTEXT)
              .margin({ left: 8 });
            Blank();
            Text(this.assignment()!.dueText)
              .fontSize(AppTheme.CAPTION_SIZE)
              .fontColor(AppTheme.TERTIARY_TEXT);
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
            .lineHeight(22)
            .fontColor(AppTheme.SUBTEXT);

          Column({ space: 9 }) {
            Text('作业资料')
              .width('100%')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            if (this.assignment()!.resourceLabels.length === 0) {
              Text('暂无老师附件').width('100%').fontSize(13).fontColor(AppTheme.SUBTEXT);
            } else {
              ForEach(this.assignment()!.resourceLabels, (label: string) => {
                Text(label).width('100%').fontSize(14).fontColor(AppTheme.TEXT);
              }, (label: string) => label);
            }
            Divider().color(AppTheme.DIVIDER);
            Text('教材 · ' + this.assignment()!.textbookRef)
              .width('100%')
              .fontSize(13)
              .fontColor(AppTheme.PRIMARY);
          }
          .width('100%')
          .padding(15)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.SURFACE_SUBTLE);

          this.SubmissionDraftPane();
          this.SavedSubmissionPane();

          Button(this.primaryActionLabel(), { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .enabled(this.primaryActionEnabled())
            .backgroundColor(this.primaryActionEnabled() ? AppTheme.PRIMARY : AppTheme.DISABLED)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => this.runPrimaryAction());
        }
        .width('100%')
        .padding(AppTheme.CARD_PADDING)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CARD_RADIUS);
      }
      .width('100%')
      .height('100%');
    }
  }

  @Builder
  private TutorPane() {
    Column({ space: 13 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.bubble_left'))
          .fontSize(22)
          .fontColor([AppTheme.PRIMARY]);
        Text('问小伴')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
      }
      .width('100%');

      if (this.tutorUnavailable) {
        Column({ space: 6 }) {
          Text('AI 辅导暂时不可用')
            .width('100%')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.WARNING);
          Text('你仍然可以查看资料、完成作业并提交。服务恢复后再继续问小伴。')
            .width('100%')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .padding(14)
        .backgroundColor(AppTheme.WARNING_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      } else {
        Text('你现在卡在哪一道题？可以先说说你已经做到哪一步。')
          .width('100%')
          .padding(14)
          .fontSize(AppTheme.BODY_SIZE)
          .lineHeight(21)
          .fontColor(AppTheme.TEXT)
          .backgroundColor(AppTheme.PRIMARY_FAINT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
        Text('小伴会先给提示，不直接替你完成作业。')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.SUBTEXT);
        TextInput({ placeholder: '输入问题…' })
          .width('100%')
          .height(AppTheme.INPUT_HEIGHT)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS);
        Row({ space: 8 }) {
          Button('语音', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(AppTheme.TEXT);
          Button('拍题', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.SURFACE_EMPHASIS)
            .fontColor(AppTheme.TEXT);
        }
        .width('100%');
      }
    }
    .width('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private CompactWorkspace() {
    if (this.compactTutorOpen) {
      Column({ space: AppTheme.ITEM_GAP }) {
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
      Column({ space: AppTheme.ITEM_GAP }) {
        Column() { this.StudyContent(); }
          .width('100%')
          .layoutWeight(1);

        Button('问小伴', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.compactTutorOpen = true);
      }
      .width('100%')
      .layoutWeight(1);
    }
  }

  build() {
    Column({ space: AppTheme.ITEM_GAP }) {
      Row() {
        Text('‹ 返回')
          .fontSize(15)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => this.onBack());
        Blank();
        if (this.assignment() !== null) {
          Text(`截至 ${this.assignment()!.dueText}`)
            .fontSize(13)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.sizeClass === WindowSizeClass.EXPANDED) {
        Row({ space: 16 }) {
          Column() { this.TaskRail(); }.width('20%');
          Column() { this.StudyContent(); }.width('50%').height('100%');
          Column() { this.TutorPane(); }.layoutWeight(1);
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top);
      } else if (this.sizeClass === WindowSizeClass.MEDIUM) {
        Row({ space: 16 }) {
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
    .padding(this.sizeClass === WindowSizeClass.EXPANDED ? AppTheme.PAGE_PADDING_WIDE : AppTheme.PAGE_PADDING)
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
