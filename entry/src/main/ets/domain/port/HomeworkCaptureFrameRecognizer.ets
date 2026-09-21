import {
  CaptureFrame,
  CaptureFrameRecognition
} from '../model/CaptureModels';

export interface HomeworkCaptureFrameRecognizer {
  recognize(frame: CaptureFrame): Promise<CaptureFrameRecognition>;
  release(): Promise<void>;
}
