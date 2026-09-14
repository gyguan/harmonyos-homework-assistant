import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { HomeworkStore } from '../../data/HomeworkStore';

const MAX_SUBMISSION_PHOTOS: number = 6;

export class HomeworkSubmissionService {
  static readonly instance: HomeworkSubmissionService = new HomeworkSubmissionService();

  private constructor() {}

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

  submit(assignmentId: string, photoUris: string[]): boolean {
    if (photoUris.length === 0 || photoUris.length > MAX_SUBMISSION_PHOTOS) {
      return false;
    }
    return HomeworkStore.instance.submitImages(assignmentId, photoUris, this.nowText());
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
