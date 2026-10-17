import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { DefaultSubmissionLocalDataSource, SubmissionLocalDataSource } from '../../data/local/SubmissionLocalDataSource';
import { DefaultAssignmentRepository } from '../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus, Submission } from '../../domain/model/HomeworkModels';
import { RemoteAssignmentMapper } from '../remote/RemoteModels';
import { RemoteSubmissionApi } from '../remote/RemoteSubmissionApi';

const MAX_SUBMISSION_PHOTOS: number = 6;
const MIN_SUBMISSION_PHOTO_EDGE: number = 640;
const MIN_SUBMISSION_PHOTO_BYTES: number = 24 * 1024;
const MIN_SUBMISSION_AUDIO_MS: number = 3 * 1000;
const MAX_SUBMISSION_AUDIO_MS: number = 10 * 60 * 1000;
const MAX_SUBMISSION_AUDIO_BYTES: number = 20 * 1024 * 1024;

export interface SubmissionPreflightResult {
  passed: boolean;
  message: string;
}

export class HomeworkSubmissionService {
  static readonly instance: HomeworkSubmissionService = new HomeworkSubmissionService();

  private context: common.UIAbilityContext | null = null;
  private readonly local: SubmissionLocalDataSource = DefaultSubmissionLocalDataSource.instance;

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
    void this.cleanupStaleSandboxCopies();
  }

  /**
   * 清理没有提交记录引用的孤儿沙盒副本。
   * 每次提交都会往 filesDir 复制一份 `homework-submission-<组>-<序号>.jpg`，
   * 中途放弃、上传失败重试、记录被清掉之后，这些副本就再也没人引用了，
   * 而它们从来没被删过——用久了能堆到几百 MB。仍在回看的提交不受影响。
   */
  private async cleanupStaleSandboxCopies(): Promise<void> {
    if (this.context === null) return;
    try {
      let referenced = this.referencedSandboxPaths();
      await this.deleteOrphanFiles(this.context.filesDir, 'homework-submission-', referenced);
      await this.deleteOrphanFiles(this.context.cacheDir, 'homework-submission-camera-', referenced);
    } catch {
      // 清理失败不影响提交主流程。
    }
  }

  private referencedSandboxPaths(): Set<string> {
    let result = new Set<string>();
    let assignments = DefaultAssignmentRepository.instance.listCached();
    for (let assignment of assignments) {
      for (let submission of this.local.listSubmissions(assignment.id)) {
        for (let uri of submission.photoUris) {
          if (uri.length > 0) result.add(uri);
        }
        if (submission.audioUri !== undefined && submission.audioUri.length > 0) {
          result.add(submission.audioUri);
        }
      }
    }
    return result;
  }

  private async deleteOrphanFiles(directory: string, prefix: string, referenced: Set<string>): Promise<void> {
    let names: string[] = [];
    try {
      names = fileIo.listFileSync(directory);
    } catch {
      return;
    }
    for (let name of names) {
      if (name.indexOf(prefix) !== 0) continue;
      let path = `${directory}/${name}`;
      let uri = fileUri.getUriFromPath(path);
      if (referenced.has(path) || referenced.has(uri)) continue;
      try {
        fileIo.unlinkSync(path);
      } catch {
        // 单个文件删不掉就跳过，下一次启动再试。
      }
    }
  }

  listCached(assignmentId: string): Submission[] {
    return this.local.listSubmissions(assignmentId);
  }

  async selectPhotos(maxSelectNumber: number = MAX_SUBMISSION_PHOTOS): Promise<string[]> {
    try {
      let safeMax = Math.max(1, Math.min(MAX_SUBMISSION_PHOTOS, maxSelectNumber));
      let picker = new photoAccessHelper.PhotoViewPicker();
      let selection = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: safeMax
      });
      return selection.photoUris.slice(0, safeMax);
    } catch {
      return [];
    }
  }

  async capturePhoto(): Promise<string> {
    if (this.context === null) return '';
    let now = Date.now();
    let filePath = `${this.context.cacheDir}/homework-submission-camera-${now}.jpg`;
    try {
      let file = fileIo.openSync(filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.closeSync(file);
      } catch {
        return '';
      }
    } catch {
      return '';
    }

    let saveUri = fileUri.getUriFromPath(filePath);
    let profile: cameraPicker.PickerProfile = {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      saveUri: saveUri
    };
    try {
      let result = await cameraPicker.pick(
        this.context, [cameraPicker.PickerMediaType.PHOTO], profile);
      if (result.resultCode !== 0) return '';
      return saveUri;
    } catch {
      return '';
    }
  }

  async preflight(photoUris: string[]): Promise<SubmissionPreflightResult> {
    if (photoUris.length === 0 || photoUris.length > MAX_SUBMISSION_PHOTOS) {
      return { passed: false, message: '请添加 1-6 张作业照片后再提交' };
    }

    let seenUris: Set<string> = new Set<string>();
    for (let index = 0; index < photoUris.length; index++) {
      let sourceUri = photoUris[index].trim();
      if (seenUris.has(sourceUri)) {
        return { passed: false, message: `第 ${index + 1} 张照片重复了，请删除重复照片后再提交` };
      }
      seenUris.add(sourceUri);

      let source: fileIo.File | null = null;
      let imageSource: image.ImageSource | null = null;
      try {
        source = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
        let stat = fileIo.statSync(source.fd);
        if (stat.size < MIN_SUBMISSION_PHOTO_BYTES) {
          return {
            passed: false,
            message: `第 ${index + 1} 张照片文件过小，请重新拍摄或选择原图`
          };
        }

        imageSource = image.createImageSource(source.fd);
        let info = await imageSource.getImageInfo(0);
        if (info.size.width < MIN_SUBMISSION_PHOTO_EDGE || info.size.height < MIN_SUBMISSION_PHOTO_EDGE) {
          return {
            passed: false,
            message: `第 ${index + 1} 张照片尺寸过小，请重新拍摄或选择原图`
          };
        }
      } catch {
        return {
          passed: false,
          message: `第 ${index + 1} 张照片无法读取，请重新选择或拍照`
        };
      } finally {
        if (imageSource !== null) {
          try {
            await imageSource.release();
          } catch {
            // Cleanup is best-effort and must not replace the photo validation result.
          }
        }
        if (source !== null) {
          try {
            await fileIo.close(source);
          } catch {
            // Cleanup is best-effort and must not replace the photo validation result.
          }
        }
      }
    }

    return { passed: true, message: '' };
  }

  async submit(assignmentId: string, photoUris: string[]): Promise<boolean> {
    if (this.context === null || photoUris.length === 0 || photoUris.length > MAX_SUBMISSION_PHOTOS) {
      return false;
    }

    let assignment = DefaultAssignmentRepository.instance.getCached(assignmentId);
    if (assignment === null) return false;

    let durableUris: string[] = [];
    let groupId = Date.now();
    for (let i = 0; i < photoUris.length; i++) {
      let durableUri = await this.copyIntoSandbox(photoUris[i], groupId, i + 1);
      durableUris.push(durableUri);
    }

    // Seed/demo assignments deliberately remain local. Any published/synced assignment must
    // wait for the backend transaction before local state is allowed to become SUBMITTED.
    if (assignment.remoteVersion <= 0 && assignment.candidateId.length === 0) {
      return this.local.submitImages(assignmentId, durableUris, this.nowText());
    }
    if (assignment.remoteVersion <= 0) return false;

    try {
      let result = await RemoteSubmissionApi.instance.uploadPhotos(
        assignmentId, assignment.remoteVersion, durableUris);

      // Record the durable local photo copies only after the server accepted the submission.
      // This local transition is immediately replaced by the authoritative server snapshot.
      this.local.submitImages(
        assignmentId, durableUris, this.submittedAtText(result.submission.submittedAt));
      let authoritative = RemoteAssignmentMapper.toLocal(result.assignment, assignment);
      DefaultAssignmentRepository.instance.applyAuthoritative(authoritative);
      return true;
    } catch {
      // A lost success response is indistinguishable from a transport failure. Refreshing here
      // makes a committed server submission visible and prevents an old client version from
      // performing a second submission on retry.
      await DefaultAssignmentRepository.instance.refresh();
      let refreshed = DefaultAssignmentRepository.instance.getCached(assignmentId);
      return refreshed !== null && refreshed.status === AssignmentStatus.SUBMITTED;
    }
  }

  async preflightAudio(audioUri: string, durationMs: number): Promise<SubmissionPreflightResult> {
    if (audioUri.length === 0) return { passed: false, message: '请先录制作业' };
    if (durationMs < MIN_SUBMISSION_AUDIO_MS) return { passed: false, message: '录音至少需要 3 秒' };
    if (durationMs > MAX_SUBMISSION_AUDIO_MS) return { passed: false, message: '单次录音不能超过 10 分钟' };
    try {
      let file = await fileIo.open(audioUri, fileIo.OpenMode.READ_ONLY);
      try {
        let stat = fileIo.statSync(file.fd);
        if (stat.size <= 0) return { passed: false, message: '录音文件为空，请重新录制' };
        if (stat.size > MAX_SUBMISSION_AUDIO_BYTES) {
          return { passed: false, message: '录音文件不能超过 20MB' };
        }
      } finally {
        try { await fileIo.close(file); } catch {}
      }
    } catch {
      return { passed: false, message: '录音文件无法读取，请重新录制' };
    }
    return { passed: true, message: '' };
  }

  async submitAudio(assignmentId: string, audioUri: string, durationMs: number): Promise<boolean> {
    let assignment = DefaultAssignmentRepository.instance.getCached(assignmentId);
    if (assignment === null) return false;
    let preflight = await this.preflightAudio(audioUri, durationMs);
    if (!preflight.passed) return false;

    if (assignment.remoteVersion <= 0 && assignment.candidateId.length === 0) {
      return this.local.submitAudio(assignmentId, audioUri, durationMs, this.nowText());
    }
    if (assignment.remoteVersion <= 0) return false;

    try {
      let result = await RemoteSubmissionApi.instance.uploadAudio(
        assignmentId, assignment.remoteVersion, audioUri, durationMs);
      this.local.submitAudio(
        assignmentId, audioUri, durationMs, this.submittedAtText(result.submission.submittedAt));
      let authoritative = RemoteAssignmentMapper.toLocal(result.assignment, assignment);
      DefaultAssignmentRepository.instance.applyAuthoritative(authoritative);
      return true;
    } catch {
      await DefaultAssignmentRepository.instance.refresh();
      let refreshed = DefaultAssignmentRepository.instance.getCached(assignmentId);
      return refreshed !== null && refreshed.status === AssignmentStatus.SUBMITTED;
    }
  }

  private async copyIntoSandbox(sourceUri: string, groupId: number, index: number): Promise<string> {
    if (this.context === null) {
      throw new Error('提交服务尚未初始化');
    }

    try {
      let source = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      try {
        let destinationPath = `${this.context.filesDir}/homework-submission-${groupId}-${index}${this.extension(sourceUri)}`;
        await fileIo.copyFile(source.fd, destinationPath, 0);
        return fileUri.getUriFromPath(destinationPath);
      } finally {
        try {
          await fileIo.close(source);
        } catch {
          // Closing is best-effort and must not replace the primary copy error.
        }
      }
    } catch {
      throw new Error('读取或保存作业照片失败');
    }
  }

  private submittedAtText(value: string): string {
    let parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return this.nowText();
    let month = this.pad(parsed.getMonth() + 1);
    let day = this.pad(parsed.getDate());
    let hour = this.pad(parsed.getHours());
    let minute = this.pad(parsed.getMinutes());
    return `${parsed.getFullYear()}-${month}-${day} ${hour}:${minute}`;
  }

  private extension(uri: string): string {
    let lower = uri.toLowerCase();
    if (lower.indexOf('.png') >= 0) {
      return '.png';
    }
    if (lower.indexOf('.jpeg') >= 0) {
      return '.jpeg';
    }
    if (lower.indexOf('.webp') >= 0) {
      return '.webp';
    }
    if (lower.indexOf('.heic') >= 0) {
      return '.heic';
    }
    return '.jpg';
  }

  private nowText(): string {
    let now = new Date();
    let month = this.pad(now.getMonth() + 1);
    let day = this.pad(now.getDate());
    let hour = this.pad(now.getHours());
    let minute = this.pad(now.getMinutes());
    return `${now.getFullYear()}-${month}-${day} ${hour}:${minute}`;
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
