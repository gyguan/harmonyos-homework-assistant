import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';

const MAX_VOICE_IMAGES_PER_PICK: number = 9;

export class VoiceAssignmentMediaService {
  static readonly instance: VoiceAssignmentMediaService = new VoiceAssignmentMediaService();
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  configure(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async selectAudio(): Promise<string> {
    if (this.context === null) throw new Error('语音选择服务尚未初始化');
    try {
      let options = new picker.AudioSelectOptions();
      options.maxSelectNumber = 1;
      let audioPicker = new picker.AudioViewPicker(this.context);
      let uris = await audioPicker.select(options);
      return uris.length > 0 ? uris[0] : '';
    } catch {
      return '';
    }
  }

  async selectImages(): Promise<string[]> {
    try {
      let imagePicker = new photoAccessHelper.PhotoViewPicker();
      let result = await imagePicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: MAX_VOICE_IMAGES_PER_PICK
      });
      return result.photoUris.slice(0, MAX_VOICE_IMAGES_PER_PICK);
    } catch {
      return [];
    }
  }

  displayName(uri: string, fallback: string): string {
    let normalized = uri;
    let query = normalized.indexOf('?');
    if (query >= 0) normalized = normalized.substring(0, query);
    let slash = normalized.lastIndexOf('/');
    let name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    if (name.length === 0) return fallback;
    try {
      return decodeURIComponent(name);
    } catch {
      return name;
    }
  }
}
