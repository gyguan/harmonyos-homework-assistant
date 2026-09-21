import nativeCapture, {
  CapturedFrame,
  CaptureStats
} from 'libhomeworkcapture.so';
import {
  CaptureFrame,
  CaptureRuntimeStats
} from '../../domain/model/CaptureModels';
import { HomeworkCaptureRuntime } from '../../domain/port/HomeworkCaptureRuntime';

export class NativeHomeworkCaptureRuntime implements HomeworkCaptureRuntime {
  static readonly instance: NativeHomeworkCaptureRuntime = new NativeHomeworkCaptureRuntime();

  startCapture(): number {
    return nativeCapture.startCapture();
  }

  stopCapture(): number {
    return nativeCapture.stopCapture();
  }

  getLatestFrame(): CaptureFrame | undefined {
    let frame: CapturedFrame | undefined = nativeCapture.getLatestFrame();
    if (!frame) return undefined;
    return {
      data: frame.data,
      width: frame.width,
      height: frame.height,
      timestamp: frame.timestamp,
      sequence: frame.sequence
    };
  }

  getStats(): CaptureRuntimeStats {
    let stats: CaptureStats = nativeCapture.getStats();
    return {
      isCapturing: stats.isCapturing,
      lastError: stats.lastError,
      state: stats.state,
      callbackCount: stats.callbackCount,
      sampledFrameCount: stats.sampledFrameCount,
      latestSequence: stats.latestSequence,
      latestWidth: stats.latestWidth,
      latestHeight: stats.latestHeight
    };
  }

  clearLatestFrame(): void {
    nativeCapture.clearLatestFrame();
  }
}
