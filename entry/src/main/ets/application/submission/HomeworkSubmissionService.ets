import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HomeworkStore } from '../../data/HomeworkStore';

const MAX_SUBMISSION_PHOTOS: number = 6;

export class HomeworkSubmissionService {
  static readonly instance: HomeworkSubmissionService = new HomeworkSubmissionService();

  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
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
    let durableUris: string[] = [];
    let groupId = Date.now();
    for (let i = 0; i < photoUris.length; i++) {
      let durableUri = await this.copyIntoSandbox(photoUris[i], groupId, i + 1);
      durableUris.push(durableUri);
    }
    return HomeworkStore.instance.submitImages(assignmentId, durableUris, this.nowText());
  }

  private async copyIntoSandbox(sourceUri: string, groupId: number, index: number): Promise<string> {
    if (this.context === null) {
      throw new Error('提交服务尚未初始化');
    }
    let source = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
    try {
      let destinationPath = `${this.context.filesDir}/homework-submission-${groupId}-${index}${this.extension(sourceUri)}`;
      await fileIo.copyFile(source.fd, destinationPath, 0);
      return fileUri.getUriFromPath(destinationPath);
    } finally {
      await fileIo.close(source);
    }
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
