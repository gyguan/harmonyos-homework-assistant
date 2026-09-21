import {
  CaptureFrame,
  CaptureRuntimeStats
} from '../model/CaptureModels';

export interface HomeworkCaptureRuntime {
  startCapture(): number;
  stopCapture(): number;
  getLatestFrame(): CaptureFrame | undefined;
  getStats(): CaptureRuntimeStats;
  clearLatestFrame(): void;
}
