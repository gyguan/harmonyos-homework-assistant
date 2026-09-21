import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { CaptureFrame } from '../../domain/model/CaptureModels';

export interface HomeworkCaptureOcrLine {
  value: string;
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface HomeworkCaptureOcrResult {
  text: string;
  blockCount: number;
  lineCount: number;
  lines: HomeworkCaptureOcrLine[];
}

export class HomeworkCaptureOcrService {
  private initialized: boolean = false;

  private async ensureInitialized(): Promise<void> {
    if (this.initialized) return;
    let ready = await textRecognition.init();
    if (!ready) throw new Error('Core Vision OCR 初始化失败');
    this.initialized = true;
  }

  private lineEvidence(line: textRecognition.TextLine): HomeworkCaptureOcrLine {
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
    return { value: line.value, left, top, right, bottom };
  }

  async recognize(frame: CaptureFrame): Promise<HomeworkCaptureOcrResult> {
    await this.ensureInitialized();
    let options: image.InitializationOptions = {
      editable: false,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      size: { width: frame.width, height: frame.height }
    };
    let pixelMap = await image.createPixelMap(frame.data, options);
    try {
      let visionInfo: textRecognition.VisionInfo = { pixelMap };
      let configuration: textRecognition.TextRecognitionConfiguration = {
        isDirectionDetectionSupported: false
      };
      let result = await textRecognition.recognizeText(visionInfo, configuration);
      let lines: HomeworkCaptureOcrLine[] = [];
      for (let block of result.blocks) {
        for (let line of block.lines) lines.push(this.lineEvidence(line));
      }
      return {
        text: result.value.trim(),
        blockCount: result.blocks.length,
        lineCount: lines.length,
        lines
      };
    } catch {
      throw new Error('Core Vision OCR 执行失败');
    } finally {
      try {
        void pixelMap.release();
      } catch {
        // PixelMap release is best-effort in the isolated capture diagnostic flow.
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
