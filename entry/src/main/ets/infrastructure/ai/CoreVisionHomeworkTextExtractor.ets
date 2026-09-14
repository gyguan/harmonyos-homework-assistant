import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkTextExtractor } from '../../domain/port/HomeworkTextExtractor';

export class CoreVisionHomeworkTextExtractor implements HomeworkTextExtractor {
  private initialized: boolean = false;

  private async ensureInitialized(): Promise<void> {
    if (this.initialized) {
      return;
    }
    let ready = await textRecognition.init();
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

    try {
      let file = await fileIo.open(input.resourceUri, fileIo.OpenMode.READ_ONLY);
      try {
        let recognizedText = '';
        try {
          let imageSource = image.createImageSource(file.fd);
          let pixelMap = await imageSource.createPixelMap();
          let visionInfo: textRecognition.VisionInfo = {
            pixelMap: pixelMap
          };
          let configuration: textRecognition.TextRecognitionConfiguration = {
            isDirectionDetectionSupported: true
          };
          let result = await textRecognition.recognizeText(visionInfo, configuration);
          recognizedText = result.value.trim();
        } catch {
          throw new Error('文字识别执行失败');
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
      } finally {
        try {
          await fileIo.close(file);
        } catch {
          // Closing is best-effort and must not hide the OCR result or primary error.
        }
      }
    } catch {
      throw new Error('无法读取或识别这张图片，请换一张更清晰的截图');
    }
  }
}
