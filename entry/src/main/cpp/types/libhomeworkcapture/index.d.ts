export interface CapturedFrame {
  data: ArrayBuffer;
  width: number;
  height: number;
  timestamp: number;
  sequence: number;
}

export interface CaptureStats {
  isCapturing: boolean;
  lastError: number;
  state: number;
  callbackCount: number;
  sampledFrameCount: number;
  latestSequence: number;
  latestWidth: number;
  latestHeight: number;
  pendingFrameCount: number;
}

export interface HomeworkCaptureNative {
  startCapture(): number;
  stopCapture(): number;
  getLatestFrame(): CapturedFrame | undefined;
  getPendingFrame(): CapturedFrame | undefined;
  getStats(): CaptureStats;
  clearLatestFrame(): void;
}

declare const homeworkCapture: HomeworkCaptureNative;
export default homeworkCapture;
