import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { DefaultSubmissionLocalDataSource, SubmissionLocalDataSource } from '../../data/local/SubmissionLocalDataSource';
import { DefaultAssignmentRepository } from '../../data/repository/DefaultAssignmentRepository';
import { Assignment, AssignmentStatus, Submission } from '../../domain/model/HomeworkModels';
import { RemoteAssignmentMapper } from '../remote/RemoteModels';
import { RemoteSubmissionApi } from '../remote/RemoteSubmissionApi';

const MAX_SUBMISSION_PHOTOS: number = 6;

export class HomeworkSubmissionService {
  static readonly instance: HomeworkSubmissionService = new HomeworkSubmissionService();

  private context: common.UIAbilityContext | null = null;
  private readonly local: SubmissionLocalDataSource = DefaultSubmissionLocalDataSource.instance;

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
  }

  listCached(assignmentId: string): Submission[] {
    return this.local.listSubmissions(assignmentId);
  }

  async selectPhotos(): Promise<string[]> {
    try {
      let picker = new photoAccessHelper.PhotoViewPicker();
      let selection = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: MAX_SUBMISSION_PHOTOS
      });
      return selection.photoUris.slice();
    } catch {
      return [];
    }
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
      let result = await RemoteSubmissionApi.instance.upload(
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
