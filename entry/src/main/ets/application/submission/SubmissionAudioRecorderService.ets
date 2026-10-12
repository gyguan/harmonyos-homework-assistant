import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';

export interface SubmissionAudioRecording {
  uri: string;
  durationMs: number;
}

export type SubmissionRecorderState = 'IDLE' | 'RECORDING' | 'PAUSED' | 'RECORDED' | 'ERROR';

export class SubmissionAudioRecorderService {
  static readonly instance: SubmissionAudioRecorderService = new SubmissionAudioRecorderService();

  private context: common.UIAbilityContext | null = null;
  private recorder: media.AVRecorder | null = null;
  private outputFile: fileIo.File | null = null;
  private outputUri: string = '';
  private stateValue: SubmissionRecorderState = 'IDLE';
  private accumulatedMs: number = 0;
  private activeStartedAtMs: number = 0;

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
  }

  state(): SubmissionRecorderState {
    return this.stateValue;
  }

  elapsedMs(): number {
    let value = this.accumulatedMs;
    if (this.stateValue === 'RECORDING' && this.activeStartedAtMs > 0) {
      value += Date.now() - this.activeStartedAtMs;
    }
    return Math.max(0, value);
  }

  async start(assignmentId: string): Promise<void> {
    if (this.context === null) throw new Error('录音服务尚未初始化');
    await this.release();
    if (!(await this.requestMicrophonePermission())) {
      throw new Error('需要麦克风权限才能录制作业');
    }
    if (!canIUse('SystemCapability.Multimedia.Media.AVRecorder')) {
      throw new Error('当前设备不支持录音');
    }

    let safeAssignmentId = assignmentId.replace(/[^a-zA-Z0-9_-]/g, '-');
    let path = `${this.context.filesDir}/submission-${safeAssignmentId}-${Date.now()}.m4a`;
    let file = await fileIo.open(path,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    this.outputFile = file;
    this.outputUri = fileUri.getUriFromPath(path);

    try {
      let recorder = await media.createAVRecorder();
      this.recorder = recorder;
      recorder.on('error', (error: BusinessError) => {
        console.error(`student submission recorder error: ${error.code} ${error.message}`);
        this.stateValue = 'ERROR';
      });
      let profile: media.AVRecorderProfile = {
        audioBitrate: 96000,
        audioChannels: 1,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48000,
        fileFormat: media.ContainerFormatType.CFT_MPEG_4A
      };
      let config: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: profile,
        url: 'fd://' + file.fd.toString()
      };
      await recorder.prepare(config);
      await recorder.start();
      this.accumulatedMs = 0;
      this.activeStartedAtMs = Date.now();
      this.stateValue = 'RECORDING';
    } catch (error) {
      this.stateValue = 'ERROR';
      await this.releaseRecorderOnly();
      await this.closeOutput();
      throw error instanceof Error ? error : new Error('录音启动失败');
    }
  }

  async pause(): Promise<void> {
    let recorder = this.recorder;
    if (recorder === null || this.stateValue !== 'RECORDING') return;
    await recorder.pause();
    this.accumulatedMs += Math.max(0, Date.now() - this.activeStartedAtMs);
    this.activeStartedAtMs = 0;
    this.stateValue = 'PAUSED';
  }

  async resume(): Promise<void> {
    let recorder = this.recorder;
    if (recorder === null || this.stateValue !== 'PAUSED') return;
    await recorder.resume();
    this.activeStartedAtMs = Date.now();
    this.stateValue = 'RECORDING';
  }

  async stop(): Promise<SubmissionAudioRecording> {
    let recorder = this.recorder;
    if (recorder === null ||
      (this.stateValue !== 'RECORDING' && this.stateValue !== 'PAUSED')) {
      throw new Error('当前没有正在录制的作业');
    }
    if (this.stateValue === 'RECORDING' && this.activeStartedAtMs > 0) {
      this.accumulatedMs += Math.max(0, Date.now() - this.activeStartedAtMs);
      this.activeStartedAtMs = 0;
    }
    await recorder.stop();
    let duration = Math.max(0, this.accumulatedMs);
    let uri = this.outputUri;
    await this.releaseRecorderOnly();
    await this.closeOutput();
    this.stateValue = 'RECORDED';
    return { uri: uri, durationMs: duration };
  }

  async release(): Promise<void> {
    let recorder = this.recorder;
    if (recorder !== null &&
      (this.stateValue === 'RECORDING' || this.stateValue === 'PAUSED')) {
      try { await recorder.stop(); } catch {}
    }
    await this.releaseRecorderOnly();
    await this.closeOutput();
    this.stateValue = 'IDLE';
    this.accumulatedMs = 0;
    this.activeStartedAtMs = 0;
  }

  private async requestMicrophonePermission(): Promise<boolean> {
    if (this.context === null) return false;
    try {
      let manager = abilityAccessCtrl.createAtManager();
      let result = await manager.requestPermissionsFromUser(
        this.context, ['ohos.permission.MICROPHONE']);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch {
      return false;
    }
  }

  private async releaseRecorderOnly(): Promise<void> {
    let recorder = this.recorder;
    this.recorder = null;
    if (recorder === null) return;
    try { recorder.off('error'); } catch {}
    try { await recorder.release(); } catch {}
  }

  private async closeOutput(): Promise<void> {
    let file = this.outputFile;
    this.outputFile = null;
    if (file === null) return;
    try { await fileIo.close(file); } catch {}
  }
}
