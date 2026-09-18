import { common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { HomeworkImportSourceKind, RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { CoreVisionHomeworkTextExtractor } from '../../infrastructure/ai/CoreVisionHomeworkTextExtractor';

export interface TutorQuestionCaptureResult {
  captured: boolean;
  imageUri: string;
  recognizedText: string;
}

export class TutorQuestionCaptureService {
  static readonly instance: TutorQuestionCaptureService = new TutorQuestionCaptureService();

  private readonly extractor: CoreVisionHomeworkTextExtractor = new CoreVisionHomeworkTextExtractor();

  private constructor() {}

  async capture(context: common.UIAbilityContext, studentId: string): Promise<TutorQuestionCaptureResult> {
    let now = Date.now();
    let filePath = `${context.cacheDir}/tutor-question-${now}.jpg`;
    try {
      let file = fileIo.openSync(filePath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.closeSync(file);
      } catch {
        return { captured: false, imageUri: '', recognizedText: '' };
      }
    } catch {
      return { captured: false, imageUri: '', recognizedText: '' };
    }
    let saveUri = fileUri.getUriFromPath(filePath);

    let profile: cameraPicker.PickerProfile = {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      saveUri: saveUri
    };

    let result: cameraPicker.PickerResult;
    try {
      result = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], profile);
    } catch {
      return { captured: false, imageUri: '', recognizedText: '' };
    }

    if (result.resultCode !== 0) {
      return { captured: false, imageUri: '', recognizedText: '' };
    }

    let candidates: string[] = [];
    candidates.push(saveUri);
    if (result.resultUri.length > 0 && result.resultUri !== saveUri) candidates.push(result.resultUri);

    let lastError = '题目图片无法识别';
    for (let uri of candidates) {
      let rawImport: RawHomeworkImport = {
        id: `tutor-question-${now}`,
        studentId: studentId,
        sourceKind: HomeworkImportSourceKind.IMAGE,
        sourceLabel: '拍题',
        resourceUri: uri,
        rawText: ''
      };
      try {
        let extracted = await this.extractor.extract(rawImport);
        return {
          captured: true,
          imageUri: uri,
          recognizedText: extracted.text
        };
      } catch (error) {
        lastError = error instanceof Error ? error.message : '题目图片无法识别';
      }
    }
    throw new Error(lastError);
  }
}
