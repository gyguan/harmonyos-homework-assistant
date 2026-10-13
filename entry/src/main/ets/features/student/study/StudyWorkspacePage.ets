import { AssignmentAudioPlayerService } from '../../../application/assignment/AssignmentAudioPlayerService';
import { HomeworkSubmissionService } from '../../../application/submission/HomeworkSubmissionService';
import { SubmissionAudioRecorderService } from '../../../application/submission/SubmissionAudioRecorderService';
import { AppTheme } from '../../../common/theme/AppTheme';
import { AssignmentCountdownCard } from '../../../components/assignment/AssignmentCountdownCard';
import { AssignmentAttachmentViewer } from '../../../components/assignment/AssignmentAttachmentViewer';
import { VoiceAssignmentPane } from '../../../components/assignment/VoiceAssignmentPane';
import { PhotoPreviewDialog } from '../../../components/submission/PhotoPreviewDialog';
import { SubmissionResumeConfirmDialog } from '../../../components/submission/SubmissionResumeConfirmDialog';
import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { Assignment, AssignmentContentType, AssignmentStatus, Submission } from '../../../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../../../domain/service/AssignmentStateMachine';
import { StudyWorkspaceViewModel } from './StudyWorkspaceViewModel';

@Component
export struct StudyWorkspacePage {
  @Prop assignmentId: string = 'a-math-001';
  @Prop revision: number = 0;
  @State private actionRevision: number = 0;
  @State private actionRunning: boolean = false;
  @State private actionMessage: string = '';
  @State private submissionPhotoUris: string[] = [];
  @State private selectingPhotos: boolean = false;
  @State private capturingPhoto: boolean = false;
  @State private submittingPhotos: boolean = false;
  @State private submissionMessage: string = '';
  @State private submissionAudioUri: string = '';
  @State private submissionAudioDurationMs: number = 0;
  @State private submissionAudioState: string = 'IDLE';
  @State private submissionRecordingElapsedMs: number = 0;
  @State private submittingAudio: boolean = false;
  @State private submissionAudioPrepared: boolean = false;
  @State private submissionAudioPlaying: boolean = false;
  @State private submissionAudioCurrentMs: number = 0;
  @State private previewUri: string = '';
  @State private resumePhotoCount: number = 0;
  @State private voiceFullscreenOpen: boolean = false;
  @State private voiceImageUris: string[] = [];
  @State private voiceImageIndex: number = 0;
  @State private voicePlaying: boolean = false;
  @State private voiceCurrentTimeMs: number = 0;
  @State private voiceDurationMs: number = 0;
  @State private voicePlaybackEnabled: boolean = false;
  @State private voicePrepared: boolean = false;
  onStoreChanged: () => void = () => {};

  private previewController: CustomDialogController = new CustomDialogController({
    builder: PhotoPreviewDialog({ uri: $previewUri }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  private resumeConfirmController: CustomDialogController = new CustomDialogController({
    builder: SubmissionResumeConfirmDialog({
      photoCount: $resumePhotoCount,
      onConfirm: () => { void this.resumeFromSubmission(); }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center,
    customStyle: true
  });

  private readonly viewModel: StudyWorkspaceViewModel =
    new StudyWorkspaceViewModel(DefaultAssignmentRepository.instance);
  private readonly submissionAudioPlayer: AssignmentAudioPlayerService =
    new AssignmentAudioPlayerService();
  private submissionRecordingTimer: number = -1;
  private pauseEmbeddedMedia: () => void = () => {};
  private voiceToggleAudio: () => void = () => {};
  private voiceSeek: (value: number) => void = (_value: number) => {};
  private voicePreviousImage: () => void = () => {};
  private voiceNextImage: () => void = () => {};
  private voiceSelectImage: (index: number) => void = (_index: number) => {};

  aboutToDisappear(): void {
    this.stopSubmissionRecordingTimer();
    void SubmissionAudioRecorderService.instance.release();
    void this.submissionAudioPlayer.release();
  }

  private isVoiceSubmission(): boolean {
    let item = this.assignment();
    return item !== null && item.contentType === AssignmentContentType.AUDIO_IMAGE;
  }

  private submissionBusy(): boolean {
    return this.selectingPhotos || this.capturingPhoto || this.submittingPhotos ||
      this.submittingAudio || this.submissionAudioState === 'RECORDING';
  }

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
        if (this.isVoiceSubmission()) {
          if (this.submittingAudio) return '正在提交录音…';
          if (this.submissionAudioState === 'RECORDING') return '请先完成录音';
          if (this.submissionAudioState === 'PAUSED') return '请先完成录音';
          return this.submissionAudioUri.length === 0 ? '请先录制作业' : '提交我的录音';
        }
        if (this.selectingPhotos) return '正在打开图库…';
        if (this.capturingPhoto) return '正在打开相机…';
        if (this.submittingPhotos) return '正在检查并提交…';
        return this.submissionPhotoUris.length === 0 ? '请先添加照片' : `确认提交 ${this.submissionPhotoUris.length} 张照片`;
      case AssignmentStatus.SUBMITTED: return '已提交';
      case AssignmentStatus.COMPLETED: return '已完成';
      default: return '继续';
    }
  }

  private primaryActionEnabled(): boolean {
    let assignment = this.assignment();
    if (assignment === null || this.actionRunning || this.submissionBusy()) return false;
    if (assignment.status === AssignmentStatus.READY_TO_SUBMIT) {
      if (this.isVoiceSubmission()) {
        return this.submissionAudioUri.length > 0 && this.submissionAudioState === 'RECORDED';
      }
      return this.submissionPhotoUris.length > 0;
    }
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
      if (this.isVoiceSubmission()) {
        if (this.submissionAudioUri.length === 0 || this.submissionAudioState !== 'RECORDED') return;
        await this.submitRecordedAudio(assignment.id);
      } else {
        if (this.submissionPhotoUris.length === 0) return;
        await this.submitSelectedPhotos(assignment.id);
      }
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
      this.actionRunning || this.submissionBusy()) return;
    let resumed = await this.executeAction(AssignmentAction.START);
    if (!resumed) return;
    if (!this.isVoiceSubmission()) this.submissionPhotoUris = [];
    this.submissionMessage = '';
  }

  private requestResumeFromSubmission(): void {
    if (this.isVoiceSubmission() || this.submissionPhotoUris.length === 0) {
      void this.resumeFromSubmission();
      return;
    }
    this.resumePhotoCount = this.submissionPhotoUris.length;
    this.resumeConfirmController.open();
  }

  private formatSubmissionTime(ms: number): string {
    let totalSeconds = Math.max(0, Math.floor(ms / 1000));
    let minutes = Math.floor(totalSeconds / 60);
    let seconds = totalSeconds % 60;
    return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private startSubmissionRecordingTimer(): void {
    this.stopSubmissionRecordingTimer();
    this.submissionRecordingTimer = setInterval(() => {
      this.submissionRecordingElapsedMs = SubmissionAudioRecorderService.instance.elapsedMs();
    }, 250);
  }

  private stopSubmissionRecordingTimer(): void {
    if (this.submissionRecordingTimer >= 0) {
      clearInterval(this.submissionRecordingTimer);
      this.submissionRecordingTimer = -1;
    }
  }

  private async startSubmissionRecording(): Promise<void> {
    if (!this.isVoiceSubmission() || this.submittingAudio ||
      this.submissionAudioState === 'RECORDING' || this.submissionAudioState === 'PAUSED') return;
    this.pauseEmbeddedMedia();
    await this.submissionAudioPlayer.release();
    this.submissionAudioPrepared = false;
    this.submissionAudioPlaying = false;
    this.submissionAudioCurrentMs = 0;
    this.submissionMessage = '';
    try {
      await SubmissionAudioRecorderService.instance.start(this.assignmentId);
      this.submissionAudioUri = '';
      this.submissionAudioDurationMs = 0;
      this.submissionRecordingElapsedMs = 0;
      this.submissionAudioState = 'RECORDING';
      this.startSubmissionRecordingTimer();
    } catch (error) {
      this.submissionAudioState = 'IDLE';
      this.submissionMessage = error instanceof Error ? error.message : '无法开始录音';
    }
  }

  private async pauseSubmissionRecording(): Promise<void> {
    if (this.submissionAudioState !== 'RECORDING') return;
    try {
      await SubmissionAudioRecorderService.instance.pause();
      this.submissionRecordingElapsedMs = SubmissionAudioRecorderService.instance.elapsedMs();
      this.submissionAudioState = 'PAUSED';
      this.stopSubmissionRecordingTimer();
    } catch {
      this.submissionMessage = '暂停录音失败，请重试';
    }
  }

  private async resumeSubmissionRecording(): Promise<void> {
    if (this.submissionAudioState !== 'PAUSED') return;
    try {
      await SubmissionAudioRecorderService.instance.resume();
      this.submissionAudioState = 'RECORDING';
      this.startSubmissionRecordingTimer();
    } catch {
      this.submissionMessage = '继续录音失败，请重试';
    }
  }

  private async finishSubmissionRecording(): Promise<void> {
    if (this.submissionAudioState !== 'RECORDING' && this.submissionAudioState !== 'PAUSED') return;
    try {
      let recording = await SubmissionAudioRecorderService.instance.stop();
      this.stopSubmissionRecordingTimer();
      this.submissionAudioUri = recording.uri;
      this.submissionAudioDurationMs = recording.durationMs;
      this.submissionRecordingElapsedMs = recording.durationMs;
      this.submissionAudioState = 'RECORDED';
      let preflight = await HomeworkSubmissionService.instance.preflightAudio(
        this.submissionAudioUri, this.submissionAudioDurationMs);
      this.submissionMessage = preflight.passed ? '录音完成，可以试听后提交' : preflight.message;
    } catch {
      this.stopSubmissionRecordingTimer();
      this.submissionAudioState = 'IDLE';
      this.submissionMessage = '录音保存失败，请重新录制';
    }
  }

  private async resetSubmissionRecording(): Promise<void> {
    this.stopSubmissionRecordingTimer();
    await SubmissionAudioRecorderService.instance.release();
    await this.submissionAudioPlayer.release();
    this.submissionAudioUri = '';
    this.submissionAudioDurationMs = 0;
    this.submissionRecordingElapsedMs = 0;
    this.submissionAudioState = 'IDLE';
    this.submissionAudioPrepared = false;
    this.submissionAudioPlaying = false;
    this.submissionAudioCurrentMs = 0;
    this.submissionMessage = '';
  }

  private async toggleSubmissionAudioPreview(): Promise<void> {
    if (this.submissionAudioUri.length === 0 || this.submissionAudioState !== 'RECORDED') return;
    if (this.submissionAudioPlaying) {
      await this.submissionAudioPlayer.pause();
      return;
    }
    if (this.submissionAudioPrepared) {
      await this.submissionAudioPlayer.play();
      return;
    }
    this.submissionMessage = '正在准备试听…';
    await this.submissionAudioPlayer.prepare(this.submissionAudioUri, {
      onPrepared: (durationMs: number) => {
        this.submissionAudioPrepared = true;
        if (durationMs > 0) this.submissionAudioDurationMs = durationMs;
        this.submissionMessage = '';
        void this.submissionAudioPlayer.play();
      },
      onState: (state) => {
        this.submissionAudioPlaying = state === 'playing';
        if (state === 'completed') this.submissionAudioCurrentMs = 0;
      },
      onTime: (timeMs: number) => this.submissionAudioCurrentMs = timeMs,
      onError: (_message: string) => {
        this.submissionAudioPlaying = false;
        this.submissionMessage = '录音试听暂不可用';
      }
    });
  }

  private async submitRecordedAudio(assignmentId: string): Promise<void> {
    if (this.submittingAudio || this.submissionAudioUri.length === 0) return;
    this.submittingAudio = true;
    this.submissionMessage = '正在检查并提交录音…';
    try {
      let preflight = await HomeworkSubmissionService.instance.preflightAudio(
        this.submissionAudioUri, this.submissionAudioDurationMs);
      if (!preflight.passed) {
        this.submissionMessage = preflight.message;
        return;
      }
      await this.submissionAudioPlayer.release();
      let submitted = await HomeworkSubmissionService.instance.submitAudio(
        assignmentId, this.submissionAudioUri, this.submissionAudioDurationMs);
      if (!submitted) {
        this.submissionMessage = '提交失败，请确认作业状态后重试';
        return;
      }
      this.submissionAudioState = 'IDLE';
      this.submissionAudioPrepared = false;
      this.submissionAudioPlaying = false;
      this.submissionMessage = '';
      this.actionRevision++;
      this.onStoreChanged();
    } catch {
      this.submissionMessage = '录音提交失败，请检查网络后重试';
    } finally {
      this.submittingAudio = false;
    }
  }

  private appendSubmissionPhotos(uris: string[]): void {
    let next = this.submissionPhotoUris.slice();
    for (let uri of uris) {
      if (uri.length === 0 || next.length >= 6) continue;
      let exists = false;
      for (let existing of next) if (existing === uri) exists = true;
      if (!exists) next.push(uri);
    }
    this.submissionPhotoUris = next;
    this.submissionMessage = next.length > 0 ? `已选择 ${next.length} 张，请确认后提交` : '';
  }

  private async selectSubmissionPhotos(): Promise<void> {
    if (this.selectingPhotos || this.capturingPhoto || this.submittingPhotos ||
      this.submissionPhotoUris.length >= 6) return;
    this.selectingPhotos = true;
    this.submissionMessage = '';
    let remaining = 6 - this.submissionPhotoUris.length;
    let selected = await HomeworkSubmissionService.instance.selectPhotos(remaining);
    this.selectingPhotos = false;
    if (selected.length === 0) return;
    this.appendSubmissionPhotos(selected);
  }

  private async captureSubmissionPhoto(): Promise<void> {
    if (this.capturingPhoto || this.selectingPhotos || this.submittingPhotos ||
      this.submissionPhotoUris.length >= 6) return;
    this.capturingPhoto = true;
    this.submissionMessage = '';
    let captured = await HomeworkSubmissionService.instance.capturePhoto();
    this.capturingPhoto = false;
    if (captured.length === 0) return;
    this.appendSubmissionPhotos([captured]);
  }

  private async submitSelectedPhotos(assignmentId: string): Promise<void> {
    if (this.submittingPhotos || this.submissionPhotoUris.length === 0) return;
    this.submittingPhotos = true;
    this.submissionMessage = '正在检查照片…';
    try {
      let preflight = await HomeworkSubmissionService.instance.preflight(this.submissionPhotoUris);
      if (!preflight.passed) {
        this.submissionMessage = preflight.message;
        return;
      }
      this.submissionMessage = '正在保存并提交…';
      let submitted = await HomeworkSubmissionService.instance.submit(assignmentId, this.submissionPhotoUris);
      if (!submitted) {
        this.submissionMessage = '提交失败，请确认作业状态后重试';
        return;
      }
      this.submissionPhotoUris = [];
      this.submissionMessage = '';
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
                .fontSize(13)
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
  private VoiceSubmissionPane() {
    Column({ space: 12 }) {
      Text('录制我的作业')
        .width('100%')
        .fontSize(AppTheme.CARD_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);

      if (this.submissionAudioState === 'IDLE') {
        Button('🎙 开始录音', { type: ButtonType.Normal })
          .width('100%')
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.submittingAudio)
          .backgroundColor(AppTheme.PRIMARY)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .onClick(() => { void this.startSubmissionRecording(); });
        Text('完成朗读或口语练习后，在这里录下你的作业。')
          .width('100%')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontColor(AppTheme.SUBTEXT);
      } else if (this.submissionAudioState === 'RECORDING' || this.submissionAudioState === 'PAUSED') {
        Column({ space: 8 }) {
          Text(this.submissionAudioState === 'RECORDING' ? '● 正在录音' : '录音已暂停')
            .fontSize(AppTheme.BODY_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.submissionAudioState === 'RECORDING' ? AppTheme.DANGER : AppTheme.WARNING);
          Text(this.formatSubmissionTime(this.submissionRecordingElapsedMs))
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 8, bottom: 8 });

        Row({ space: 10 }) {
          Button(this.submissionAudioState === 'RECORDING' ? '暂停' : '继续录音', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .onClick(() => {
              if (this.submissionAudioState === 'RECORDING') void this.pauseSubmissionRecording();
              else void this.resumeSubmissionRecording();
            });
          Button('完成录音', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .onClick(() => { void this.finishSubmissionRecording(); });
        }
        .width('100%');
      } else {
        Row({ space: 12 }) {
          Button(this.submissionAudioPlaying ? 'Ⅱ' : '▶', { type: ButtonType.Circle })
            .width(48)
            .height(48)
            .backgroundColor(AppTheme.PRIMARY)
            .fontColor(AppTheme.TEXT_ON_PRIMARY)
            .accessibilityText(this.submissionAudioPlaying ? '暂停试听' : '播放录音')
            .onClick(() => { void this.toggleSubmissionAudioPreview(); });
          Column({ space: 3 }) {
            Text('我的录音')
              .fontSize(AppTheme.BODY_SIZE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.TEXT);
            Text(`${this.formatSubmissionTime(this.submissionAudioCurrentMs)} / ${this.formatSubmissionTime(this.submissionAudioDurationMs)}`)
              .fontSize(AppTheme.META_SIZE)
              .fontColor(AppTheme.SUBTEXT);
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start);
          Text('重新录音')
            .constraintSize({ minHeight: AppTheme.MIN_TOUCH_TARGET })
            .padding({ left: 8, right: 8 })
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.PRIMARY)
            .accessibilityRole(AccessibilityRoleType.BUTTON)
            .onClick(() => { void this.resetSubmissionRecording(); });
        }
        .width('100%')
        .padding(10)
        .backgroundColor(AppTheme.SURFACE)
        .borderRadius(AppTheme.CONTROL_RADIUS);
      }

      if (this.submissionMessage.length > 0) {
        Text(this.submissionMessage)
          .width('100%')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontColor(AppTheme.PRIMARY);
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private PhotoSubmissionPane() {
    Column({ space: 10 }) {
      Text('提交作业照片')
        .width('100%')
        .fontSize(AppTheme.CARD_TITLE_SIZE)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.TEXT);
      if (this.submissionPhotoUris.length > 0) {
        this.PhotoStrip(this.submissionPhotoUris, true);
      }
      Row({ space: 10 }) {
        Button(this.selectingPhotos ? '正在打开图库…' : '从图库选择', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.selectingPhotos && !this.capturingPhoto && !this.submittingPhotos &&
            this.submissionPhotoUris.length < 6)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => { void this.selectSubmissionPhotos(); });
        Button(this.capturingPhoto ? '正在打开相机…' : '拍照', { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.SECONDARY_BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(!this.selectingPhotos && !this.capturingPhoto && !this.submittingPhotos &&
            this.submissionPhotoUris.length < 6)
          .backgroundColor(AppTheme.PRIMARY_SOFT)
          .fontColor(AppTheme.PRIMARY)
          .onClick(() => { void this.captureSubmissionPhoto(); });
      }
      .width('100%');
      Text(this.submissionPhotoUris.length === 0 ?
        '可从图库选择或直接拍照，最多 6 张。' :
        '请确认照片清晰、完整，页数和顺序无误。')
        .width('100%')
        .fontSize(AppTheme.META_SIZE)
        .lineHeight(AppTheme.META_LINE_HEIGHT)
        .fontColor(AppTheme.SUBTEXT);
      if (this.submissionMessage.length > 0) {
        Text(this.submissionMessage)
          .width('100%')
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .lineHeight(AppTheme.ACTION_TEXT_LINE_HEIGHT)
          .fontColor(AppTheme.PRIMARY);
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(AppTheme.PRIMARY_FAINT)
    .borderRadius(AppTheme.CONTROL_RADIUS);
  }

  @Builder
  private SubmissionPane() {
    if (this.assignment() !== null && this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT &&
      !this.isVoiceSubmission()) {
      this.PhotoSubmissionPane();
    }

    if (this.submissions().length > 0) {
      Column({ space: 8 }) {
        Text(`已提交 · ${this.submissions()[0].fileLabel}`)
          .width('100%')
          .fontSize(AppTheme.META_SIZE)
          .lineHeight(AppTheme.META_LINE_HEIGHT)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.SUCCESS);
        if (this.submissions()[0].photoUris.length > 0) {
          this.PhotoStrip(this.submissions()[0].photoUris, false);
        }
      }
      .width('100%')
      .padding(AppTheme.CARD_PADDING_COMPACT)
      .backgroundColor(AppTheme.SUCCESS_SOFT)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private ResourcePane() {
    if (this.assignment() !== null && this.assignment()!.contentType !== AssignmentContentType.AUDIO_IMAGE &&
      this.assignment()!.resourceLabels.length > 0) {
      Row() {
        Column({ space: 3 }) {
          Text('老师附件')
            .fontSize(AppTheme.LABEL_TITLE_SIZE)
            .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
            .fontColor(AppTheme.TERTIARY_TEXT);
          Text(`${this.assignment()!.resourceLabels.length} 项资料`)
            .fontSize(AppTheme.BODY_SIZE)
            .lineHeight(AppTheme.BODY_LINE_HEIGHT)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.TEXT);
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start);
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor(AppTheme.SURFACE_SUBTLE)
      .borderRadius(AppTheme.CONTROL_RADIUS);
    }
  }

  @Builder
  private VoiceAssignmentContent(playbackEnabled: boolean, imageOnlyMode: boolean) {
    VoiceAssignmentPane({
      assignmentId: this.assignmentId,
      playbackEnabled: playbackEnabled,
      imageOnlyMode: imageOnlyMode,
      onPauseReady: (pause: () => void) => this.pauseEmbeddedMedia = pause,
      onFullscreenRequest: () => this.voiceFullscreenOpen = true,
      onFullscreenDismissed: () => this.voiceFullscreenOpen = false,
      onMediaStateChanged: (
        imageUris: string[],
        imageIndex: number,
        playing: boolean,
        currentTimeMs: number,
        durationMs: number,
        currentPlaybackEnabled: boolean,
        prepared: boolean
      ) => this.applyVoiceMediaState(
        imageUris, imageIndex, playing, currentTimeMs, durationMs, currentPlaybackEnabled, prepared),
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

  @Builder
  private StudyContent(showPrimaryAction: boolean) {
    if (this.assignment() === null) {
      Column({ space: 8 }) {
        Text('找不到这项作业')
          .fontSize(AppTheme.SECTION_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.TEXT);
        Text('这项作业可能已经被删除或切换。').fontSize(AppTheme.META_SIZE).lineHeight(AppTheme.META_LINE_HEIGHT).fontColor(AppTheme.SUBTEXT);
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    } else {
      Scroll() {
        Column({ space: 18 }) {
          if (this.assignment()!.contentType !== AssignmentContentType.AUDIO_IMAGE) {
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
          }

          Text(this.assignment()!.title)
            .width('100%')
            .fontSize(AppTheme.PAGE_TITLE_SIZE)
            .lineHeight(AppTheme.PAGE_TITLE_LINE_HEIGHT)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.TEXT)
            .maxLines(AppTheme.CARD_TITLE_MAX_LINES)
            .textOverflow({ overflow: TextOverflow.Ellipsis });

          if (this.assignment()!.contentType !== AssignmentContentType.AUDIO_IMAGE) {
            AssignmentAttachmentViewer({ assignmentId: this.assignment()!.id });
          }

          if (this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT ||
            this.assignment()!.status === AssignmentStatus.SUBMITTED ||
            this.assignment()!.status === AssignmentStatus.COMPLETED) {
            Row({ space: 10 }) {
              SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                .fontSize(24)
                .fontColor([AppTheme.SUCCESS]);
              Text(this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT ?
                (this.isVoiceSubmission() ? '看着图片完成朗读，录音时可以左右切换图片。' :
                  '最后一步：添加清晰、完整的作业照片。') :
                (this.assignment()!.status === AssignmentStatus.SUBMITTED ?
                  (this.isVoiceSubmission() ? '录音已提交，等待家长确认。' :
                    '照片已提交，等待家长确认。') : '这项作业已经完成。'))
                .layoutWeight(1)
                .fontSize(AppTheme.READING_BODY_SIZE)
                .lineHeight(AppTheme.READING_BODY_LINE_HEIGHT)
                .fontColor(AppTheme.TEXT);
            }
            .width('100%')
            .padding(14)
            .backgroundColor(AppTheme.SUCCESS_SOFT)
            .borderRadius(AppTheme.CONTROL_RADIUS);

            if (this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT &&
              this.isVoiceSubmission()) {
              this.VoiceAssignmentContent(false, true);
              this.VoiceSubmissionPane();
            } else {
              this.SubmissionPane();
            }
          } else {
            if (this.assignment()!.reviewNote.length > 0) {
              Column({ space: 5 }) {
                Text('需要先订正')
                  .width('100%')
                  .fontSize(AppTheme.LABEL_TITLE_SIZE)
                  .lineHeight(AppTheme.LABEL_TITLE_LINE_HEIGHT)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppTheme.DANGER);
                Text(this.assignment()!.reviewNote)
                  .width('100%')
                  .fontSize(AppTheme.READING_BODY_SIZE)
                  .lineHeight(AppTheme.READING_BODY_LINE_HEIGHT)
                  .fontColor(AppTheme.TEXT);
              }
              .width('100%')
              .padding(14)
              .backgroundColor(AppTheme.DANGER_SOFT)
              .borderRadius(AppTheme.CONTROL_RADIUS);
            }

            if (this.assignment()!.contentType !== AssignmentContentType.AUDIO_IMAGE) {
              Text(this.assignment()!.instruction.length > 0 ?
                this.assignment()!.instruction : '按课堂要求完成这项作业。')
                .width('100%')
                .fontSize(AppTheme.READING_BODY_SIZE)
                .lineHeight(AppTheme.READING_BODY_LINE_HEIGHT)
                .fontColor(AppTheme.TEXT);
            }

            if (this.assignment()!.contentType === AssignmentContentType.AUDIO_IMAGE) {
              this.VoiceAssignmentContent(
                this.assignment()!.status === AssignmentStatus.IN_PROGRESS, false);
            }

            if (this.assignment()!.status === AssignmentStatus.IN_PROGRESS ||
              this.assignment()!.status === AssignmentStatus.PAUSED) {
              AssignmentCountdownCard({ assignment: this.assignment()! });
            }
            this.ResourcePane();
          }

          if (this.actionMessage.length > 0) {
            Text(this.actionMessage)
              .width('100%')
              .fontSize(AppTheme.META_SIZE)
              .lineHeight(AppTheme.META_LINE_HEIGHT)
              .fontColor(AppTheme.WARNING);
          }

          if (showPrimaryAction) {
            Button(this.primaryActionLabel(), { type: ButtonType.Normal })
              .width('100%')
              .height(AppTheme.BUTTON_HEIGHT)
              .borderRadius(AppTheme.CONTROL_RADIUS)
              .enabled(this.primaryActionEnabled())
              .backgroundColor(this.primaryActionEnabled() ? AppTheme.PRIMARY : AppTheme.DISABLED)
              .fontColor(AppTheme.TEXT_ON_PRIMARY)
              .fontSize(AppTheme.ACTION_TEXT_SIZE)
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
  private WorkspaceActionBar() {
    if (this.assignment() !== null &&
      this.assignment()!.status !== AssignmentStatus.SUBMITTED &&
      this.assignment()!.status !== AssignmentStatus.COMPLETED) {
      Row({ space: 10 }) {
        if (this.assignment()!.status === AssignmentStatus.IN_PROGRESS) {
          Button('暂停一下', { type: ButtonType.Normal })
            .width(112)
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.actionRunning)
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .accessibilityText('暂停作业计时')
            .onClick(() => { void this.pauseCurrentAssignment(); });
        }

        if (this.assignment()!.status === AssignmentStatus.READY_TO_SUBMIT) {
          Button('继续作业', { type: ButtonType.Normal })
            .width(112)
            .height(AppTheme.BUTTON_HEIGHT)
            .borderRadius(AppTheme.CONTROL_RADIUS)
            .enabled(!this.actionRunning && !this.submissionBusy())
            .backgroundColor(AppTheme.PRIMARY_SOFT)
            .fontColor(AppTheme.PRIMARY)
            .fontSize(AppTheme.ACTION_TEXT_SIZE)
            .accessibilityText('返回作业继续完成')
            .onClick(() => this.requestResumeFromSubmission());
        }

        Button(this.primaryActionLabel(), { type: ButtonType.Normal })
          .layoutWeight(1)
          .height(AppTheme.BUTTON_HEIGHT)
          .borderRadius(AppTheme.CONTROL_RADIUS)
          .enabled(this.primaryActionEnabled())
          .backgroundColor(this.primaryActionEnabled() ? AppTheme.PRIMARY : AppTheme.DISABLED)
          .fontColor(AppTheme.TEXT_ON_PRIMARY)
          .fontSize(AppTheme.ACTION_TEXT_SIZE)
          .fontWeight(FontWeight.Medium)
          .onClick(() => { void this.runPrimaryAction(); });
      }
      .width('100%')
      .padding({ top: 2, bottom: 4 });
    }
  }

  @Builder
  private VoiceFullscreenImage() {
    Stack({ alignContent: Alignment.Center }) {
      Swiper() {
        ForEach(this.voiceImageUris, (uri: string, index: number) => {
          Stack({ alignContent: Alignment.Center }) {
            if (uri.length > 0) {
              Image(uri)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Contain);
            } else {
              LoadingProgress()
                .width(32)
                .height(32)
                .color(AppTheme.PRIMARY);
            }
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#111111');
        }, (uri: string, index: number) => `${index}-${uri}`);
      }
      .width('100%')
      .height('100%')
      .index(this.voiceImageIndex)
      .indicator(false)
      .loop(true)
      .onChange((index: number) => {
        this.voiceImageIndex = index;
        this.voiceSelectImage(index);
      });

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
            Stack({ alignContent: Alignment.Center }) {
              if (uri.length > 0) {
                Image(uri)
                  .width(68)
                  .height(56)
                  .objectFit(ImageFit.Cover);
              } else {
                Text(`${index + 1}`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#D8D8D8');
              }
            }
            .width(68)
            .height(56)
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
          Text(this.formatVoiceTime(this.voiceCurrentTimeMs)).fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor('#D8D8D8');
          Blank();
          Text(this.formatVoiceTime(this.voiceDurationMs)).fontSize(AppTheme.CAPTION_SIZE).lineHeight(AppTheme.CAPTION_LINE_HEIGHT).fontColor('#D8D8D8');
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
  private UnifiedWorkspace() {
    Column({ space: 10 }) {
      Column() {
        this.StudyContent(false);
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start);

      this.WorkspaceActionBar();
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.UnifiedWorkspace();

      if (this.voiceFullscreenOpen && this.voiceImageUris.length > 0) {
        this.VoiceFullscreenOverlay();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppTheme.BACKGROUND);
  }
}
