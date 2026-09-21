import { HomeworkCaptureSessionService } from '../../main/ets/application/capture/HomeworkCaptureSessionService';
import { HomeworkImportInboxService } from '../../main/ets/application/import/HomeworkImportInboxService';
import {
  CaptureFrame,
  CaptureFrameRecognition,
  CaptureRuntimeStats,
  CaptureSessionStatus
} from '../../main/ets/domain/model/CaptureModels';
import { HomeworkCaptureFrameRecognizer } from '../../main/ets/domain/port/HomeworkCaptureFrameRecognizer';
import { HomeworkCaptureRuntime } from '../../main/ets/domain/port/HomeworkCaptureRuntime';

class FixtureCaptureRuntime implements HomeworkCaptureRuntime {
  private started: boolean = false;
  private index: number = 0;
  private frames: CaptureFrame[] = [];

  constructor() {
    this.frames = [
      this.frame(1, 12),
      this.frame(2, 88),
      this.frame(3, 88)
    ];
  }

  private frame(sequence: number, value: number): CaptureFrame {
    let bytes = new Uint8Array(384);
    bytes.fill(value);
    return {
      data: bytes.buffer,
      width: 12,
      height: 8,
      timestamp: 1726848000000 + sequence * 1000,
      sequence: sequence
    };
  }

  startCapture(): number {
    this.started = true;
    this.index = 0;
    return 0;
  }

  stopCapture(): number {
    this.started = false;
    return 0;
  }

  advance(): void {
    if (this.index < this.frames.length - 1) this.index++;
  }

  getLatestFrame(): CaptureFrame | undefined {
    if (!this.started && this.index === 0) return undefined;
    return this.frames[this.index];
  }

  getStats(): CaptureRuntimeStats {
    return {
      isCapturing: this.started,
      lastError: 0,
      callbackCount: this.started ? this.index + 1 : this.index + 1,
      sampledFrameCount: this.index + 1,
      latestSequence: this.frames[this.index].sequence
    };
  }

  clearLatestFrame(): void {
    this.index = 0;
  }
}

class FixtureCaptureRecognizer implements HomeworkCaptureFrameRecognizer {
  async recognize(frame: CaptureFrame): Promise<CaptureFrameRecognition> {
    if (frame.sequence === 1) {
      return {
        text: '17:31 王老师 今晚语文作业：第8课生字写两遍',
        lineCount: 1,
        lines: [{
          value: '17:31 王老师 今晚语文作业：第8课生字写两遍',
          left: 80, top: 180, right: 620, bottom: 220
        }]
      };
    }
    return {
      text: '17:32 王老师 补充：朗读第8课三遍',
      lineCount: 1,
      lines: [{
        value: '17:32 王老师 补充：朗读第8课三遍',
        left: 80, top: 360, right: 620, bottom: 400
      }]
    };
  }

  async release(): Promise<void> {}
}

export interface Issue244FixtureResult {
  sessionId: string;
  batchId: string;
  frameCount: number;
  acceptedFrameCount: number;
  messageCount: number;
  passed: boolean;
}

export class Issue244CaptureSessionFixture {
  static async run(studentId: string): Promise<Issue244FixtureResult> {
    if (HomeworkCaptureSessionService.instance.getActiveSession() !== null) {
      throw new Error('请先结束真实采集，再运行 #244 Fixture');
    }

    let runtime = new FixtureCaptureRuntime();
    HomeworkCaptureSessionService.instance.configure(runtime, new FixtureCaptureRecognizer());
    try {
      let session = HomeworkCaptureSessionService.instance.start(studentId, 'issue244-fixture');
      await HomeworkCaptureSessionService.instance.sampleLatestFrame();
      runtime.advance();
      await HomeworkCaptureSessionService.instance.sampleLatestFrame();
      runtime.advance();
      await HomeworkCaptureSessionService.instance.sampleLatestFrame();
      let completed = await HomeworkCaptureSessionService.instance.stopByUser();
      if (completed === null) throw new Error('#244 Fixture 未能完成 Session');

      let batch = HomeworkImportInboxService.instance.getBatch(completed.importBatchId);
      let messages = HomeworkImportInboxService.instance.getMessages(completed.importBatchId);
      let passed = completed.status === CaptureSessionStatus.COMPLETED &&
        completed.acceptedFrameCount === 2 &&
        batch !== null &&
        batch.captureSessionId === completed.id &&
        messages.length === 2;

      return {
        sessionId: completed.id,
        batchId: completed.importBatchId,
        frameCount: completed.frameCount,
        acceptedFrameCount: completed.acceptedFrameCount,
        messageCount: messages.length,
        passed: passed
      };
    } finally {
      let active = HomeworkCaptureSessionService.instance.getActiveSession();
      if (active !== null && active.sourceProfileId === 'issue244-fixture') {
        await HomeworkCaptureSessionService.instance.cancel();
      }
    }
  }
}
