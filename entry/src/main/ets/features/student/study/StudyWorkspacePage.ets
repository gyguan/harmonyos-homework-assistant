import { TutorChatMessage, TutorConversation, TutorRemoteApi } from '../../../application/remote/TutorRemoteApi';
import { HomeworkSubmissionService } from '../../../application/submission/HomeworkSubmissionService';
import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCountdownCard } from '../../../components/assignment/AssignmentCountdownCard';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { TutorQuestionCapturePanel } from '../../../components/tutor/TutorQuestionCapturePanel';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { Assignment, AssignmentStatus, Submission } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';
import { StudyWorkspaceViewModel } from './StudyWorkspaceViewModel';

@Component
export struct StudyWorkspacePage {
  @Prop tutorUnavailable: boolean = false;
  @Prop assignmentId: string = 'a-math-001';
  @Prop revision: number = 0;
  @State private actionRevision: number = 0;
  @State private actionRunning: boolean = false;
  @State private actionMessage: string = '';
  @State private tutorPanelOpen: boolean = false;
  @State private availableWidthVp: number = 390;
  @State private submissionPhotoUris: string[] = [];
  @State private selectingPhotos: boolean = false;
  @State private submittingPhotos: boolean = false;
  @State private submissionMessage: string = '';
  @State private tutorDraft: string = '';
  @State private tutorMessages: TutorChatMessage[] = [];
  @State private tutorNotice: string = '';
  @State private tutorAvailable: boolean = false;
  @State private tutorLoading: boolean = false;
  @State private tutorSending: boolean = false;
  onBack: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private readonly viewModel: StudyWorkspaceViewModel =
    new StudyWorkspaceViewModel(DefaultAssignmentRepository.instance);

  aboutToAppear(): void { void this.loadTutor(); }

  private canUseTutorSplit(): boolean {
    return LayoutPolicy.canSplit(this.availableWidthVp, LayoutPolicy.studyTutorRequirement());
  }

  private showTutorAsStandalone(): boolean {
    return !this.canUseTutorSplit() && this.tutorPanelOpen;
  }

  private assignment(): Assignment | null {
    let currentRevision = this.revision + this.actionRevision;
    if (currentRevision < 0) return null;
    return this.viewModel.assignment(this.assignmentId);
  }

  private submissions(): Submission[] {
    let currentRevision = this.revision + this.actionRevision;
    if (currentRevision < 0) return [];
    return HomeworkSubmissionService.instance.listCached(this.assignmentId);
  }

  private async loadTutor(): Promise<void> {
    if (this.tutorUnavailable || this.assignmentId.length === 0 || this.tutorLoading) return;
    this.tutorLoading = true;
    let conversation = await TutorRemoteApi.instance.load(this.assignmentId);
    this.applyTutor(conversation);
    this.tutorLoading = false;
  }

  private applyTutor(conversation: TutorConversation): void {
    this.tutorMessages = conversation.messages.slice();
    this.tutorAvailable = conversation.available;
    this.tutorNotice = conversation.notice;
  }

  private async askTutor(): Promise<void> {
    let text = this.tutorDraft.trim();
    if (text.length === 0 || this.tutorSending) return;
    this.tutorSending = true;
    this.tutorNotice = '小伴正在想怎么提示你…';
    let conversation = await TutorRemoteApi.instance.ask(this.assignmentId, text);
    this.applyTutor(conversation);
    if (conversation.available) this.tutorDraft = '';
    this.tutorSending = false;
  }

  private primaryActionLabel(): string {
    if (this.actionRunning) return '处理中…';
    let assignment = this.assignment();
    if (assignment === null) return '作业不存在';
    switch (assignment.status) {
      case AssignmentStatus.NOT_STARTED:
      case AssignmentStatus.OVERDUE:
      case AssignmentStatus.NEEDS_REWORK: return '开始作业';
      case AssignmentStatus.PAUSED: return '继续作业';
      case AssignmentStatus.IN_PROGRESS: return '我做完了，准备提交';
      case AssignmentStatus.READY_TO_SUBMIT:
        if (this.selectingPhotos) return '正在打开相册…';
        if (this.submittingPhotos) return '正在保存并提交…';
        return this.submissionPhotoUris.length === 0 ? '选择作业照片' : `确认提交 ${this.submissionPhotoUris.length} 张照片`;
      case AssignmentStatus.SUBMITTED: return '已提交';
      case AssignmentStatus.COMPLETED: return '已完成';
      default: return '继续';
    }
  }

  private primaryActionEnabled(): boolean {
    let assignment = this.assignment();
    if (assignment === null || this.actionRunning || this.selectingPhotos || this.submittingPhotos) return false;
    return assignment.status !== AssignmentStatus.SUBMITTED && assignment.status !== AssignmentStatus.COMPLETED;
  }

  private async runPrimaryAction(): Promise<void> {
    let assignment = this.assignment();
    if (assignment === null || this.actionRunning) return;
    if (assignment.status === AssignmentStatus.NOT_STARTED || assignment.status === AssignmentStatus.OVERDUE ||
      assignment.status === AssignmentStatus.NEEDS_REWORK || assignment.status === AssignmentStatus.PAUSED) {
      await this.executeAction(AssignmentAction.START);
    } else if (assignment.status === AssignmentStatus.IN_PROGRESS) {
      await this.executeAction(AssignmentAction.READY_TO_SUBMIT);
    } else if (assignment.status === AssignmentStatus.READY_TO_SUBMIT) {
      if (this.submissionPhotoUris.length === 0) {
        await this.selectSubmissionPhotos();
        return;
      }
      await this.submitSelectedPhotos(assignment.id);
    }
  }

  private async pauseCurrentAssignment(): Promise<void> {
    let assignment = this.assignment();
    if (assignment === null || assignment.status !== AssignmentStatus.IN_PROGRESS || this.actionRunning) return;
    await this.executeAction(AssignmentAction.PAUSE);
  }

  private async executeAction(action: AssignmentAction): Promise<void> {
    if (this.actionRunning) return;
    this.actionRunning = true;
    this.actionMessage = '';
    try {
      await this.viewModel.performAction(this.assignmentId, action);
      this.actionRevision++;
    } catch {
      this.actionMessage = '状态更新失败，请检查网络并刷新后重试';
    } finally {
      this.actionRunning = false;
    }
  }

  private async selectSubmissionPhotos(): Promise<void> {
    if (this.selectingPhotos || this.submittingPhotos) return;
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
    if (this.submittingPhotos || this.submissionPhotoUris.length === 0) return;
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
      this.actionRevision++;
      this.onStoreChanged();
    } catch {
      this.submissionMessage = '照片保存失败，请重新选择后再试';
    } finally {
      this.submittingPhotos = false;
    }
  }

  private removeSubmissionPhoto(uri: string): void {
    let next: string[] = [];
    for (let item of this.submissionPhotoUris) if (item !== uri) next.push(item);
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
                .width(64)
                .height(AppTheme.MIN_TOUCH_TARGET)
                .fontSize(12)
                .fontColor(AppTheme.DANGER)
                .textAlign(TextAlign.Center)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText('移除这张作业照片')
                .onClick(() => this.removeSubmissionPhoto(uri));
            }
          }
          .width(96);
        }, (uri: string) => uri);
      }
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off);
  }

  @Builder
  private SubmissionPane() {
    if (this.assignment() !== null && this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT) {
      Column({ space: 10 }) {
        Text('提交作业照片')
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        if (this.submissionPhotoUris.length > 0) {
          this.PhotoStrip(this.submissionPhotoUris, true);
          Button('重新选择照片', { type: ButtonType.Normal })
            .width('100%')
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.submittingPhotos)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => { void this.selectSubmissionPhotos(); });
        }
        Text(this.submissionPhotoUris.length === 0 ? '从系统相册选择已经拍好的作业照片，最多 6 张。' : '请确认照片清晰、完整，页数和顺序无误。')
          .width('100%')
          .fontSize(13)
          .fontColor(AppTheme.SUBTEXT);
        if (this.submissionMessage.length > 0) {
          Text(this.submissionMessage)
            .width('100%')
            .fontSize(12)
            .fontColor(AppTheme.PRIMARY);
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor(AppTheme.PRIMARY_FAINT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }

    if (this.submissions().length > 0) {
      Column({ space: 8 }) {
        Text(`已提交 · ${this.submissions()[0].fileLabel}`)
          .width('100%')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUCCESS);
        if (this.submissions()[0].photoUris.length > 0) {
          this.PhotoStrip(this.submissions()[0].photoUris, false);
        }
      }
      .width('100%')
      .padding(13)
      .backgroundColor(AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private ResourcePane() {
    if (this.assignment() !== null) {
      Column({ space: 0 }) {
        Row() {
          Column({ space: 3 }) {
            Text('教材 / 页码').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
            Text(this.assignment()!.textbookRef.length > 0 ? this.assignment()!.textbookRef : '未设置')
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 });

        Divider().color(AppTheme.DIVIDER);

        Row() {
          Column({ space: 3 }) {
            Text('老师附件').fontSize(12).fontColor(AppTheme.TERTIARY_TEXT);
            Text(this.assignment()!.resourceLabels.length === 0 ? '暂无附件' : `${this.assignment()!.resourceLabels.length} 项资料`)
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(AppTheme.TEXT);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 });
      }
      .width('100%')
      .padding({ left: 14, right: 14 })
      .backgroundColor(AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private StudyContent(showPrimaryAction: boolean) {
    if (this.assignment() === null) {
      Column({ space: 8 }) {
        Text('找不到这项作业')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('这项作业可能已经被删除或切换。').fontSize(13).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    } else {
      Scroll() {
        Column({ space: 18 }) {
          Row({ space: 8 }) {
            Text(this.assignment()!.subject)
              .fontSize(AppTheme.CAPTION_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.PRIMARY);
            Text('·').fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
            Text(AssignmentStateMachine.label(this.assignment()!.status))
              .fontSize(AppTheme.CAPTION_SIZE)
              .fontColor(AppTheme.SUBTEXT);
            Blank();
            Text(`截至 ${this.assignment()!.dueText}`).fontSize(AppTheme.CAPTION_SIZE).fontColor(AppTheme.TERTIARY_TEXT);
          }
          .width('100%');

          Text(this.assignment()!.title)
            .width('100%')
            .fontSize(AppTheme.STUDY_TITLE_SIZE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);

          Text(this.assignment()!.instruction)
            .width('100%')
            .fontSize(15)
            .lineHeight(23)
            .fontColor(AppTheme.SUBTEXT);

          AssignmentCountdownCard({ assignment: this.assignment()! });

          if (this.actionMessage.length > 0) {
            Text(this.actionMessage)
              .width('100%')
              .fontSize(12)
              .fontColor(AppTheme.WARNING);
          }

          if (this.assignment()!.status === AssignmentStatus.IN_PROGRESS) {
            Row() {
              Blank();
              Text('暂停一下')
                .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
                .fontSize(13)
                .fontColor(AppTheme.SUBTEXT)
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText('暂停作业计时')
                .onClick(() => { void this.pauseCurrentAssignment(); });
            }
            .width('100%');
          }

          this.ResourcePane();
          this.SubmissionPane();

          if (showPrimaryAction) {
            Button(this.primaryActionLabel(), { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(this.primaryActionEnabled())
              .backgroundColor(this.primaryActionEnabled() ? AppTheme.PRIMARY : AppTheme.DISABLED)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .onClick(() => { void this.runPrimaryAction(); });
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({ top: 0, bottom: 16 });
      }
      .width('100%')
      .height('100%')
      .align(Alignment.TopStart)
      .scrollBar(BarState.Off)
      .backgroundColor(AppTheme.BACKGROUND);
    }
  }

  @Builder
  private TutorPane() {
    Column({ space: 12 }) {
      Row() {
        Text('问小伴')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Blank();
        if (this.tutorLoading) {
          Text('同步中').fontSize(11).fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%');

      if (this.tutorUnavailable) {
        Text('AI 辅导暂时不可用，但作业查看与提交不受影响。')
          .width('100%')
          .padding(14)
          .fontSize(13)
          .fontColor(AppTheme.WARNING)
          .backgroundColor(AppTheme.WARNING_SOFT)
          .borderRadius(AppTheme.CONTROL_RADIUS);
      } else {
        Scroll() {
          Column({ space: 9 }) {
            if (this.tutorMessages.length === 0) {
              Text('你现在卡在哪一步？先告诉小伴你已经尝试了什么。')
                .width('100%')
                .padding(13)
                .fontSize(14)
                .lineHeight(21)
                .fontColor(AppTheme.TEXT)
                .backgroundColor(AppTheme.PRIMARY_FAINT)
                .borderRadius(AppTheme.CONTROL_RADIUS);
            }
            ForEach(this.tutorMessages, (message: TutorChatMessage) => {
              Row() {
                if (message.role === 'USER') Blank();
                Text(message.content)
                  .constraintSize({ maxWidth: '86%' })
                  .padding(11)
                  .fontSize(14)
                  .lineHeight(21)
                  .fontColor(message.role === 'USER' ? AppTheme.TEXT_ON_PRIMARY : AppTheme.TEXT)
                  .backgroundColor(message.role === 'USER' ? AppTheme.PRIMARY : AppTheme.SURFACE_SUBTLE)
                  .borderRadius(AppTheme.CONTROL_RADIUS);
                if (message.role !== 'USER') Blank();
              }
              .width('100%');
            }, (message: TutorChatMessage) => message.id);
          }
          .width('100%');
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);

        if (this.tutorNotice.length > 0) {
          Text(this.tutorNotice)
            .width('100%')
            .fontSize(12)
            .fontColor(this.tutorAvailable ? AppTheme.SUBTEXT : AppTheme.WARNING);
        }

        Text('小伴默认提示优先，不直接替你完成作业。')
          .width('100%')
          .fontSize(AppTheme.CAPTION_SIZE)
          .fontColor(AppTheme.SUBTEXT);

        TutorQuestionCapturePanel({
          studentId: this.viewModel.studentId(),
          onRecognized: (text: string) => {
            this.tutorDraft = `题目识别结果：\n${text}\n\n我卡住的地方：`;
            this.tutorNotice = '识别文字已放入输入框，请确认或补充后再发送';
          }
        });

        TextArea({ placeholder: '输入问题，或者说说你做到哪一步…', text: this.tutorDraft })
          .width('100%')
          .height(110)
          .backgroundColor(AppTheme.SURFACE_SUBTLE)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .onChange((value: string) => this.tutorDraft = value);

        Button(this.tutorSending ? '发送中…' : '发送给小伴', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.tutorSending && this.tutorDraft.trim().length > 0)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => { void this.askTutor(); });
      }
    }
    .width('100%')
    .height('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private PageHeader() {
    DeepPageHeader({
      title: this.showTutorAsStandalone() ? '问小伴' : '学习空间',
      subtitle: this.assignment() === null ? '' : this.assignment()!.subject,
      trailingText: this.showTutorAsStandalone() || this.assignment() === null ? '' : this.assignment()!.dueText,
      backAccessibilityText: this.showTutorAsStandalone() ? '返回学习任务' : '返回上一页',
      onBack: () => {
        if (this.showTutorAsStandalone()) this.tutorPanelOpen = false;
        else this.onBack();
      }
    });
  }

  @Builder
  private SingleColumnWorkspace() {
    if (this.tutorPanelOpen) {
      Column() {
        this.TutorPane();
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start);
    } else {
      Column({ space: 10 }) {
        Column() {
          this.StudyContent(false);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start);

        Row({ space: 10 }) {
          Button('问小伴', { type: ButtonType.Normal })
            .width(120)
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => {
              this.tutorPanelOpen = true;
              void this.loadTutor();
            });

          Button(this.primaryActionLabel(), { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(this.primaryActionEnabled())
            .backgroundColor(this.primaryActionEnabled() ? AppTheme.PRIMARY : AppTheme.DISABLED)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .onClick(() => { void this.runPrimaryAction(); });
        }
        .width('100%')
        .padding({ top: 2, bottom: 4 });
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start);
    }
  }

  @Builder
  private SplitWorkspace() {
    Row({ space: AppTheme.SPLIT_PANE_GAP }) {
      Column({ space: 10 }) {
        Column() {
          this.StudyContent(false);
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start);

        Button(this.primaryActionLabel(), { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(this.primaryActionEnabled())
          .backgroundColor(this.primaryActionEnabled() ? AppTheme.PRIMARY : AppTheme.DISABLED)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .onClick(() => { void this.runPrimaryAction(); });
      }
      .layoutWeight(1)
      .height('100%')
      .constraintSize({ minWidth: AppTheme.STUDY_PRIMARY_MIN_WIDTH })
      .alignItems(HorizontalAlign.Start);

      Column() {
        this.TutorPane();
      }
      .width(AppTheme.STUDY_TUTOR_MIN_WIDTH)
      .height('100%')
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(VerticalAlign.Top);
  }

  @Builder
  private PhoneWorkspacePage() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      this.PageHeader();
      this.SingleColumnWorkspace();
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppTheme.STUDY_READABLE_MAX_WIDTH })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: AppTheme.PAGE_PADDING,
      right: AppTheme.PAGE_PADDING,
      top: AppTheme.DEEP_PAGE_TOP_PADDING,
      bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING
    });
  }

  @Builder
  private PadWorkspacePage() {
    Column({ space: AppTheme.DEEP_PAGE_CONTENT_GAP }) {
      this.PageHeader();
      this.SplitWorkspace();
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppTheme.STUDY_SPLIT_MAX_WIDTH })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: AppTheme.PAGE_PADDING_WIDE,
      right: AppTheme.PAGE_PADDING_WIDE,
      top: AppTheme.DEEP_PAGE_TOP_PADDING,
      bottom: AppTheme.DEEP_PAGE_BOTTOM_PADDING
    });
  }

  build() {
    Row() {
      if (this.canUseTutorSplit()) {
        this.PadWorkspacePage();
      } else {
        this.PhoneWorkspacePage();
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Top)
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = ResponsiveContext.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
