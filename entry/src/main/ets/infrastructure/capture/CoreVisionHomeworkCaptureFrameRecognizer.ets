import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import {
  CaptureFrame,
  CaptureFrameRecognition
} from '../../domain/model/CaptureModels';
import { HomeworkCaptureFrameRecognizer } from '../../domain/port/HomeworkCaptureFrameRecognizer';

export class CoreVisionHomeworkCaptureFrameRecognizer implements HomeworkCaptureFrameRecognizer {
  private initialized: boolean = false;

  private async ensureInitialized(): Promise<void> {
    if (this.initialized) return;
    let ready = await textRecognition.init();
    if (!ready) throw new Error('采集文字识别服务初始化失败');
    this.initialized = true;
  }

  async recognize(frame: CaptureFrame): Promise<CaptureFrameRecognition> {
    await this.ensureInitialized();
    let options: image.InitializationOptions = {
      editable: false,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      size: {
        width: frame.width,
        height: frame.height
      }
    };
    let pixelMap = await image.createPixelMap(frame.data, options);
    try {
      let visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      let configuration: textRecognition.TextRecognitionConfiguration = {
        isDirectionDetectionSupported: false
      };
      let result = await textRecognition.recognizeText(visionInfo, configuration);
      let lineCount = 0;
      for (let block of result.blocks) lineCount += block.lines.length;
      return {
        text: result.value.trim(),
        lineCount: lineCount
      };
    } finally {
      try {
        void pixelMap.release();
      } catch {
        // PixelMap release is best-effort after OCR completes.
      }
    }
  }

  async release(): Promise<void> {
    if (!this.initialized) return;
    try {
      await textRecognition.release();
    } finally {
      this.initialized = false;
    }
  }
}
