import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkTextExtractor } from '../../domain/port/HomeworkTextExtractor';

export class CoreVisionHomeworkTextExtractor implements HomeworkTextExtractor {
  private initialized: boolean = false;

  private recognitionError(stage: string, message: string, cause: BusinessError | null | undefined): Error {
    let code = cause !== null && cause !== undefined && typeof cause.code === 'number' &&
      Number.isFinite(cause.code) ? cause.code : 0;
    // Only stage and numeric code are safe: native messages may contain image paths/content.
    console.warn(`Homework OCR failed stage=${stage} code=${code}`);
    if (stage === 'recognize' && code === 1001400002) this.initialized = false;
    return new Error(code === 0 ? message : `${message}（错误码 ${code}）`);
  }

  private async ensureInitialized(): Promise<void> {
    if (this.initialized) {
      return;
    }
    if (!canIUse('SystemCapability.AI.OCR.TextRecognition')) {
      throw new Error('文字识别服务初始化失败，当前设备不支持本机文字识别');
    }
    let ready = false;
    try {
      ready = await textRecognition.init();
    } catch (error) {
      throw this.recognitionError('init', '文字识别服务初始化失败，请稍后重试', error as BusinessError);
    }
    if (!ready) {
      throw new Error('文字识别服务初始化失败');
    }
    this.initialized = true;
  }

  async extract(input: RawHomeworkImport): Promise<ExtractedHomeworkText> {
    let existingText = input.rawText.trim();
    if (existingText.length > 0) {
      return {
        importId: input.id,
        studentId: input.studentId,
        sourceLabel: input.sourceLabel,
        text: existingText
      };
    }
    if (input.resourceUri.length === 0) {
      throw new Error('没有可识别的图片');
    }

    await this.ensureInitialized();

    let file: fileIo.File | null = null;
    let imageSource: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    let recognizedText = '';
    let stage = 'read';
    try {
      file = await fileIo.open(input.resourceUri, fileIo.OpenMode.READ_ONLY);
      stage = 'decode';
      imageSource = image.createImageSource(file.fd);
      // CoreVision only accepts RGBA_8888. Explicit SDR also normalizes HDR gallery photos.
      let options: image.DecodingOptions = {
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredDynamicRange: image.DecodingDynamicRange.SDR
      };
      pixelMap = await imageSource.createPixelMap(options);
      stage = 'recognize';
      let visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      let configuration: textRecognition.TextRecognitionConfiguration = {
        isDirectionDetectionSupported: true
      };
      let result = await textRecognition.recognizeText(visionInfo, configuration);
      recognizedText = result.value.trim();
    } catch (error) {
      let message = '文字识别失败，请稍后重试或使用图片解析';
      if (stage === 'read') message = '无法读取这张图片，请重新选择';
      if (stage === 'decode') message = '图片解码失败，请换一张截图重试';
      throw this.recognitionError(stage, message, error as BusinessError);
    } finally {
      // Cleanup is best effort: continue releasing other resources and preserve the primary result/error.
      if (pixelMap !== null) {
        try { await pixelMap.release(); } catch { console.warn('Homework OCR pixel cleanup failed'); }
      }
      if (imageSource !== null) {
        try { await imageSource.release(); } catch { console.warn('Homework OCR source cleanup failed'); }
      }
      if (file !== null) {
        try { await fileIo.close(file); } catch { console.warn('Homework OCR file cleanup failed'); }
      }
    }
    if (recognizedText.length === 0) {
      throw new Error('没有识别到文字，请换一张更清晰的截图');
    }
    return {
      importId: input.id,
      studentId: input.studentId,
      sourceLabel: input.sourceLabel,
      text: recognizedText
    };
  }
}
