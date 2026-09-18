import { TutorChatMessage, TutorConversation, TutorRemoteApi } from '../../../application/remote/TutorRemoteApi';
import { HomeworkSubmissionService } from '../../../application/submission/HomeworkSubmissionService';
import { LayoutPolicy } from '../../../common/responsive/LayoutPolicy';
import { ResponsiveContext } from '../../../common/responsive/WindowSizeClass';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCountdownCard } from '../../../components/assignment/AssignmentCountdownCard';
import { VoiceAssignmentPane } from '../../../components/assignment/VoiceAssignmentPane';
import { CenteredTextBadge } from '../../../components/family/CenteredTextBadge';
import { DeepPageHeader } from '../../../components/navigation/DeepPageHeader';
import { PhotoPreviewDialog } from '../../../components/submission/PhotoPreviewDialog';
import { TutorQuestionCapturePanel } from '../../../components/tutor/TutorQuestionCapturePanel';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { Assignment, AssignmentContentType, AssignmentStatus, Submission } from '../../../domain/model/HomeworkModels';
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
  @State private previewUri: string = '';
  @State private tutorDraft: string = '';
  @State private tutorMessages: TutorChatMessage[] = [];
  @State private tutorNotice: string = '';
  @State private tutorAvailable: boolean = false;
  @State private tutorHasMore: boolean = false;
  @State private tutorNextBeforeEpochMs: number = 0;
  @State private tutorLoading: boolean = false;
  @State private tutorLoadingOlder: boolean = false;
  @State private tutorSending: boolean = false;
  @State private voiceFullscreenOpen: boolean = false;
  @State private voiceImageUris: string[] = [];
  @State private voiceImageIndex: number = 0;
  @State private voicePlaying: boolean = false;
  @State private voiceCurrentTimeMs: number = 0;
  @State private voiceDurationMs: number = 0;
  @State private voicePlaybackEnabled: boolean = false;
  @State private voicePrepared: boolean = false;
  onBack: () => void = () => {};
  onStoreChanged: () => void = () => {};

  private previewController: CustomDialogController = new CustomDialogController({
    builder: PhotoPreviewDialog({ uri: $previewUri }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  private readonly viewModel: StudyWorkspaceViewModel =
    new StudyWorkspaceViewModel(DefaultAssignmentRepository.instance);
  private pauseEmbeddedMedia: () => void = () => {};
  private voiceToggleAudio: () => void = () => {};
  private voiceSeek: (value: number) => void = (_value: number) => {};
  private voicePreviousImage: () => void = () => {};
  private voiceNextImage: () => void = () => {};
  private voiceSelectImage: (index: number) => void = (_index: number) => {};

  aboutToAppear(): void { void this.loadTutor(); }

  private applyVoiceMediaState(
    imageUris: string[],
    imageIndex: number,
    playing: boolean,
    currentTimeMs: number,
    durationMs: number,
    playbackEnabled: boolean,
    prepared: boolean
  ): void {
    this.voiceImageUris = imageUris.slice();
    this.voiceImageIndex = imageIndex;
    this.voicePlaying = playing;
    this.voiceCurrentTimeMs = currentTimeMs;
    this.voiceDurationMs = durationMs;
    this.voicePlaybackEnabled = playbackEnabled;
    this.voicePrepared = prepared;
  }

  private closeVoiceFullscreen(): void {
    this.voiceFullscreenOpen = false;
  }

  private formatVoiceTime(ms: number): string {
    let totalSeconds = Math.max(0, Math.floor(ms / 1000));
    let minutes = Math.floor(totalSeconds / 60);
    let seconds = totalSeconds % 60;
    return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

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
    this.tutorHasMore = conversation.hasMore;
    this.tutorNextBeforeEpochMs = conversation.nextBeforeEpochMs;
  }

  private async loadOlderTutor(): Promise<void> {
    if (!this.tutorHasMore || this.tutorNextBeforeEpochMs <= 0 || this.tutorLoadingOlder) return;
    this.tutorLoadingOlder = true;
    let older = await TutorRemoteApi.instance.load(this.assignmentId, this.tutorNextBeforeEpochMs);
    let merged: TutorChatMessage[] = [];
    let seen: Set<string> = new Set<string>();
    for (let item of older.messages) {
      if (seen.has(item.id)) continue;
      seen.add(item.id);
      merged.push(item);
    }
    for (let item of this.tutorMessages) {
      if (seen.has(item.id)) continue;
      seen.add(item.id);
      merged.push(item);
    }
    this.tutorMessages = merged;
    this.tutorHasMore = older.hasMore;
    this.tutorNextBeforeEpochMs = older.nextBeforeEpochMs;
    if (older.notice.length > 0) this.tutorNotice = older.notice;
    this.tutorLoadingOlder = false;
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

  private fillTutorPrompt(prompt: string): void {
    this.tutorDraft = prompt;
    this.tutorNotice = '';
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
      this.pauseEmbeddedMedia();
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
    this.pauseEmbeddedMedia();
    await this.executeAction(AssignmentAction.PAUSE);
  }

  private async executeAction(action: AssignmentAction): Promise<boolean> {
    if (this.actionRunning) return false;
    this.actionRunning = true;
    this.actionMessage = '';
    try {
      await this.viewModel.performAction(this.assignmentId, action);
      this.actionRevision++;
      this.onStoreChanged();
      return true;
    } catch {
      this.actionMessage = '状态更新失败，请刷新作业状态后重试';
      return false;
    } finally {
      this.actionRunning = false;
    }
  }

  private async resumeFromSubmission(): Promise<void> {
    let assignment = this.assignment();
    if (assignment === null || assignment.status !== AssignmentStatus.READY_TO_SUBMIT ||
      this.actionRunning || this.submittingPhotos) return;
    let resumed = await this.executeAction(AssignmentAction.START);
    if (!resumed) return;
    this.submissionPhotoUris = [];
    this.submissionMessage = '已返回作业，可继续完成后再提交';
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

  private openPhotoPreview(uri: string): void {
    if (uri.length === 0) return;
    this.previewUri = uri;
    this.previewController.open();
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
              .backgroundColor(AppTheme.SURFACE_EMPHASIS)
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText('查看作业照片大图')
              .onClick(() => this.openPhotoPreview(uri));
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
        Text(this.submissionPhotoUris.length === 0 ?
          '从系统相册选择已经拍好的作业照片，最多 6 张；如果还没做完，可点击底部“继续作业”。' :
          '请确认照片清晰、完整，页数和顺序无误；需要继续完成时可点击底部“继续作业”。')
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
    if (this.assignment() !== null && this.assignment()!.contentType !== AssignmentContentType.AUDIO_IMAGE) {
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

          if (this.assignment()!.contentType === AssignmentContentType.AUDIO_IMAGE) {
            VoiceAssignmentPane({
              assignmentId: this.assignment()!.id,
              playbackEnabled: this.assignment()!.status === AssignmentStatus.IN_PROGRESS,
              onPauseReady: (pause: () => void) => this.pauseEmbeddedMedia = pause,
              onFullscreenRequest: () => this.voiceFullscreenOpen = true,
              onFullscreenDismissed: () => this.voiceFullscreenOpen = false,
              onMediaStateChanged: (
                imageUris: string[],
                imageIndex: number,
                playing: boolean,
                currentTimeMs: number,
                durationMs: number,
                playbackEnabled: boolean,
                prepared: boolean
              ) => this.applyVoiceMediaState(
                imageUris, imageIndex, playing, currentTimeMs, durationMs, playbackEnabled, prepared),
              onFullscreenControlsReady: (
                toggleAudio: () => void,
                seek: (value: number) => void,
                previousImage: () => void,
                nextImage: () => void,
                selectImage: (index: number) => void
              ) => {
                this.voiceToggleAudio = toggleAudio;
                this.voiceSeek = seek;
                this.voicePreviousImage = previousImage;
                this.voiceNextImage = nextImage;
                this.voiceSelectImage = selectImage;
              }
            });
          }

          AssignmentCountdownCard({ assignment: this.assignment()! });

          if (this.actionMessage.length > 0) {
            Text(this.actionMessage)
              .width('100%')
              .fontSize(12)
              .fontColor(AppTheme.WARNING);
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
  private WorkspaceActionBar(showTutorEntry: boolean) {
    Row({ space: 10 }) {
      if (showTutorEntry) {
        Button('问小伴', { type: ButtonType.Normal })
          .width(this.assignment() !== null &&
            (this.assignment()!.status === AssignmentStatus.IN_PROGRESS ||
              this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT) ? 88 : 112)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .fontSize(13)
          .onClick(() => {
            this.tutorPanelOpen = true;
            void this.loadTutor();
          });
      }

      if (this.assignment() !== null && this.assignment()!.status === AssignmentStatus.IN_PROGRESS) {
        Button('暂停一下', { type: ButtonType.Normal })
          .width(showTutorEntry ? 88 : 112)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.actionRunning)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .fontSize(13)
          .accessibilityText('暂停作业计时')
          .onClick(() => { void this.pauseCurrentAssignment(); });
      }

      if (this.assignment() !== null && this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT) {
        Button('继续作业', { type: ButtonType.Normal })
          .width(showTutorEntry ? 88 : 112)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.actionRunning && !this.submittingPhotos)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .fontSize(13)
          .accessibilityText('返回作业继续完成')
          .onClick(() => { void this.resumeFromSubmission(); });
      }

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

  @Builder
  private TutorSuggestion(label: string, prompt: string) {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(36)
      .borderRadius(AppTheme.CONTROL_RADIUS)
      .backgroundColor(AppTheme.SURFACE)
      .fontColor(AppTheme.PRIMARY)
      .fontSize(12)
      .border({ width: 1, color: AppTheme.BORDER })
      .onClick(() => this.fillTutorPrompt(prompt));
  }

  @Builder
  private TutorPane() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        CenteredTextBadge({
          badgeText: '伴',
          badgeWidth: 40,
          badgeHeight: 40,
          badgeFontSize: 15,
          badgeRadius: 20,
          badgeBold: true,
          badgeForeground: AppTheme.PRIMARY,
          badgeBackground: AppTheme.PRIMARY_SOFT
        });

        Column({ space: 2 }) {
          Text('小伴学习助手')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('先帮你理思路，再给下一步提示')
            .fontSize(11)
            .fontColor(AppTheme.SUBTEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);

        if (this.tutorLoading) {
          Text('同步中')
            .fontSize(11)
            .fontColor(AppTheme.SUBTEXT);
        }
      }
      .width('100%')
      .padding({ bottom: 12 });

      Divider().color(AppTheme.DIVIDER);

      if (this.tutorUnavailable) {
        Column({ space: 8 }) {
          Text('小伴暂时休息一下')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
          Text('AI 辅导暂时不可用，但作业查看、计时和提交都不受影响。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(AppTheme.SUBTEXT);
        }
        .width('100%')
        .padding({ top: 24, bottom: 24, left: 14, right: 14 })
        .backgroundColor(AppTheme.WARNING_SOFT)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      } else {
        Scroll() {
          Column({ space: 12 }) {
            if (this.tutorHasMore) {
              Text(this.tutorLoadingOlder ? '正在加载更早记录…' : '查看更早的对话')
                .width('100%')
                .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
                .fontSize(12)
                .fontColor(AppTheme.PRIMARY)
                .textAlign(TextAlign.Center)
                .accessibilityRole(AccessibilityRoleType.BUTTON)
                .accessibilityText('加载更早的小伴对话')
                .onClick(() => { void this.loadOlderTutor(); });
            }

            if (this.tutorMessages.length === 0 && !this.tutorLoading) {
              Column({ space: 12 }) {
                CenteredTextBadge({
                  badgeText: '伴',
                  badgeWidth: 48,
                  badgeHeight: 48,
                  badgeFontSize: 17,
                  badgeRadius: 24,
                  badgeBold: true,
                  badgeForeground: AppTheme.PRIMARY,
                  badgeBackground: AppTheme.PRIMARY_SOFT
                });
                Text('有哪里卡住了？')
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.TEXT);
                Text('先说说你已经做到哪一步，小伴会给提示，不会直接替你完成。')
                  .width('100%')
                  .fontSize(13)
                  .lineHeight(20)
                  .textAlign(TextAlign.Center)
                  .fontColor(AppTheme.SUBTEXT);

                Row({ space: 8 }) {
                  this.TutorSuggestion('怎么开始？', '这题我不知道怎么开始，请先给我一个提示。');
                  this.TutorSuggestion('检查思路', '我已经有一个思路了，请帮我检查哪里需要调整。');
                  this.TutorSuggestion('提示下一步', '我做到一半卡住了，请只提示我下一步怎么想。');
                }
                .width('100%');
              }
              .width('100%')
              .padding({ top: 28, bottom: 24, left: 8, right: 8 })
              .alignItems(HorizontalAlign.Center);
            }

            ForEach(this.tutorMessages, (message: TutorChatMessage) => {
              if (message.role === 'USER') {
                Row({ space: 8 }) {
                  Blank();
                  Text(message.content)
                    .constraintSize({ maxWidth: '82%' })
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .fontSize(14)
                    .lineHeight(21)
                    .fontColor(AppTheme.TEXT_ON_PRIMARY)
                    .backgroundColor(AppTheme.PRIMARY)
                    .borderRadius(14);
                }
                .width('100%')
                .alignItems(VerticalAlign.Bottom);
              } else {
                Row({ space: 8 }) {
                  CenteredTextBadge({
                    badgeText: '伴',
                    badgeWidth: 28,
                    badgeHeight: 28,
                    badgeFontSize: 11,
                    badgeRadius: 14,
                    badgeBold: true,
                    badgeForeground: AppTheme.PRIMARY,
                    badgeBackground: AppTheme.PRIMARY_SOFT
                  });
                  Text(message.content)
                    .constraintSize({ maxWidth: '82%' })
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .fontSize(14)
                    .lineHeight(21)
                    .fontColor(AppTheme.TEXT)
                    .backgroundColor(AppTheme.SURFACE_SUBTLE)
                    .borderRadius(14);
                  Blank();
                }
                .width('100%')
                .alignItems(VerticalAlign.Top);
              }
            }, (message: TutorChatMessage) => message.id);
          }
          .width('100%')
          .padding({ top: 14, bottom: 14 });
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off);

        if (this.tutorNotice.length > 0) {
          Text(this.tutorNotice)
            .width('100%')
            .padding({ top: 6, bottom: 6 })
            .fontSize(11)
            .fontColor(this.tutorAvailable ? AppTheme.SUBTEXT : AppTheme.WARNING);
        }

        Column({ space: 8 }) {
          Row() {
            Text('你的问题')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Blank();
            Text('文字提问或拍题')
              .fontSize(11)
              .fontColor(AppTheme.SUBTEXT);
          }
          .width('100%');

          TextArea({ placeholder: '说说你卡在哪一步…', text: this.tutorDraft })
            .width('100%')
            .height(82)
            .backgroundColor(AppTheme.SURFACE)
            .border({ width: 1, color: AppTheme.BORDER })
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .onChange((value: string) => this.tutorDraft = value);

          Row({ space: 10 }) {
            TutorQuestionCapturePanel({
              studentId: this.viewModel.studentId(),
              onRecognized: (text: string) => {
                this.tutorDraft = `题目识别结果：\n${text}\n\n我卡住的地方：`;
                this.tutorNotice = '识别文字已填入，请确认或补充后再发送';
              }
            })
            .layoutWeight(1);

            Button(this.tutorSending ? '发送中…' : '发送', { type: ButtonType.Normal })
              .width(88)
              .height(38)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(!this.tutorSending && this.tutorDraft.trim().length > 0)
              .backgroundColor(!this.tutorSending && this.tutorDraft.trim().length > 0 ?
                AppTheme.PRIMARY : AppTheme.DISABLED)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .onClick(() => { void this.askTutor(); });
          }
          .width('100%')
          .alignItems(VerticalAlign.Center);
        }
        .width('100%')
        .padding(10)
        .backgroundColor(AppTheme.SURFACE_SUBTLE)
        .border({ width: 1, color: AppTheme.BORDER })
        .borderRadius(AppTheme.CARD_RADIUS);
      }
    }
    .width('100%')
    .height('100%')
    .padding(AppTheme.CARD_PADDING)
    .backgroundColor(AppTheme.SURFACE)
    .borderRadius(AppTheme.CARD_RADIUS);
  }

  @Builder
  private VoiceFullscreenImage() {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.voiceImageUris[this.voiceImageIndex])
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .backgroundColor('#111111');

      if (this.voiceImageUris.length > 1) {
        Row() {
          Button('←', { type: ButtonType.Circle })
            .width(48)
            .height(48)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#E6FFFFFF')
            .fontColor(AppTheme.TEXT)
            .accessibilityText('上一张情景图片')
            .onClick(() => this.voicePreviousImage());
          Blank();
          Button('→', { type: ButtonType.Circle })
            .width(48)
            .height(48)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#E6FFFFFF')
            .fontColor(AppTheme.TEXT)
            .accessibilityText('下一张情景图片')
            .onClick(() => this.voiceNextImage());
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 12, right: 12 });
      }
    }
    .width('100%')
    .layoutWeight(1);
  }

  @Builder
  private VoiceFullscreenThumbnails() {
    if (this.voiceImageUris.length > 1) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.voiceImageUris, (uri: string, index: number) => {
            Image(uri)
              .width(68)
              .height(56)
              .objectFit(ImageFit.Cover)
              .border({
                width: index === this.voiceImageIndex ? 2 : 1,
                color: index === this.voiceImageIndex ? AppTheme.PRIMARY : '#666666'
              })
              .borderRadius(10)
              .backgroundColor('#242424')
              .accessibilityRole(AccessibilityRoleType.BUTTON)
              .accessibilityText(`查看第 ${index + 1} 张情景图片`)
              .onClick(() => this.voiceSelectImage(index));
          }, (uri: string, index: number) => `${index}-${uri}`);
        }
      }
      .width('100%')
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off);
    }
  }

  @Builder
  private VoiceFullscreenAudio() {
    Row({ space: 12 }) {
      Button(this.voicePlaying ? 'Ⅱ' : '▶', { type: ButtonType.Circle })
        .width(52)
        .height(52)
        .fontSize(this.voicePlaying ? 19 : 17)
        .enabled(this.voicePlaybackEnabled && this.voicePrepared)
        .backgroundColor(this.voicePlaybackEnabled && this.voicePrepared ? AppTheme.PRIMARY : AppTheme.DISABLED)
        .fontColor(AppTheme.TEXT_ON_PRIMARY)
        .accessibilityText(this.voicePlaying ? '暂停语音' : '播放语音')
        .onClick(() => this.voiceToggleAudio());

      Column({ space: 2 }) {
        Slider({
          value: this.voiceCurrentTimeMs,
          min: 0,
          max: this.voiceDurationMs > 0 ? this.voiceDurationMs : 1,
          step: 1000,
          style: SliderStyle.InSet
        })
          .width('100%')
          .selectedColor(AppTheme.PRIMARY)
          .trackColor('#4A4A4A')
          .enabled(this.voicePlaybackEnabled && this.voicePrepared)
          .onChange((value: number, mode: SliderChangeMode) => {
            this.voiceCurrentTimeMs = value;
            if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
              this.voiceSeek(value);
            }
          });

        Row() {
          Text(this.formatVoiceTime(this.voiceCurrentTimeMs)).fontSize(11).fontColor('#D8D8D8');
          Blank();
          Text(this.formatVoiceTime(this.voiceDurationMs)).fontSize(11).fontColor('#D8D8D8');
        }
        .width('100%');
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .padding({ top: 8, bottom: 4 });
  }

  @Builder
  private VoiceFullscreenOverlay() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text(`${this.voiceImageIndex + 1} / ${this.voiceImageUris.length}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF');
        Blank();
        Button('关闭', { type: ButtonType.Normal })
          .width(72)
          .height(40)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#3A3A3A')
          .borderRadius(20)
          .accessibilityText('退出全屏')
          .onClick(() => this.closeVoiceFullscreen());
      }
      .width('100%')
      .alignItems(VerticalAlign.Center);

      this.VoiceFullscreenImage();
      this.VoiceFullscreenThumbnails();
      this.VoiceFullscreenAudio();
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor('#111111');
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

        this.WorkspaceActionBar(true);
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

        this.WorkspaceActionBar(false);
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
    Stack({ alignContent: Alignment.TopStart }) {
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
      .backgroundColor(AppTheme.BACKGROUND);

      if (this.voiceFullscreenOpen && this.voiceImageUris.length > 0) {
        this.VoiceFullscreenOverlay();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND)
    .onAreaChange((_oldValue, newValue) => {
      this.availableWidthVp = ResponsiveContext.areaLengthToVp(newValue.width, this.availableWidthVp);
    });
  }
}
