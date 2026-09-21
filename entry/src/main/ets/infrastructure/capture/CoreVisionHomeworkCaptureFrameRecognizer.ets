import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import {
  CaptureFrame,
  CaptureFrameRecognition,
  CaptureOcrLineEvidence
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
      let lines: CaptureOcrLineEvidence[] = [];
      for (let block of result.blocks) {
        for (let line of block.lines) {
          let left = 0;
          let top = 0;
          let right = 0;
          let bottom = 0;
          if (line.cornerPoints.length > 0) {
            left = line.cornerPoints[0].x;
            right = line.cornerPoints[0].x;
            top = line.cornerPoints[0].y;
            bottom = line.cornerPoints[0].y;
            for (let point of line.cornerPoints) {
              if (point.x < left) left = point.x;
              if (point.x > right) right = point.x;
              if (point.y < top) top = point.y;
              if (point.y > bottom) bottom = point.y;
            }
          }
          lines.push({
            value: line.value.trim(),
            left: left,
            top: top,
            right: right,
            bottom: bottom
          });
        }
      }
      return {
        text: result.value.trim(),
        lineCount: lines.length,
        lines: lines
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
