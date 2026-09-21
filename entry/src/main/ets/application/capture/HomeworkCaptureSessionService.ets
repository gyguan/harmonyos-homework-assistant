import { HomeworkImportInboxService } from '../import/HomeworkImportInboxService';
import { HomeworkCaptureSessionStore } from '../../data/local/HomeworkCaptureSessionStore';
import {
  CaptureFrame,
  CaptureFrameEvidence,
  CaptureSession,
  CaptureSessionStatus,
  CaptureStopReason
} from '../../domain/model/CaptureModels';
import {
  HomeworkImportSourceType,
  ImportBatch,
  ImportBatchStatus,
  ImportedMessage
} from '../../domain/model/ImportModels';
import { HomeworkCaptureFrameRecognizer } from '../../domain/port/HomeworkCaptureFrameRecognizer';
import { HomeworkCaptureRuntime } from '../../domain/port/HomeworkCaptureRuntime';

const FRAME_DIFF_THRESHOLD: number = 10;
const SIGNATURE_SAMPLES: number = 96;

export class HomeworkCaptureSessionService {
  static readonly instance: HomeworkCaptureSessionService = new HomeworkCaptureSessionService();

  private runtime: HomeworkCaptureRuntime | null = null;
  private recognizer: HomeworkCaptureFrameRecognizer | null = null;
  private readonly store: HomeworkCaptureSessionStore = HomeworkCaptureSessionStore.instance;
  private lastSignature: number[] = [];
  private signatureSessionId: string = '';
  private sampleInFlight: Promise<CaptureSession | null> | null = null;

  private constructor() {}

  configure(runtime: HomeworkCaptureRuntime, recognizer: HomeworkCaptureFrameRecognizer): void {
    this.runtime = runtime;
    this.recognizer = recognizer;
  }

  getActiveSession(): CaptureSession | null {
    return this.store.getActiveSession();
  }

  getSession(sessionId: string): CaptureSession | null {
    return this.store.getSession(sessionId);
  }

  getEvidence(sessionId: string): CaptureFrameEvidence[] {
    return this.store.getEvidence(sessionId);
  }

  start(studentId: string, sourceProfileId: string = ''): CaptureSession {
    let existing = this.store.getActiveSession();
    if (existing !== null) throw new Error('已有作业采集正在进行，请先结束当前采集');

    let runtime = this.requireRuntime();
    let now = Date.now();
    let session: CaptureSession = {
      id: `capture-${now}`,
      studentId: studentId,
      startedAtEpochMs: now,
      stoppedAtEpochMs: 0,
      status: CaptureSessionStatus.CREATED,
      frameCount: 0,
      acceptedFrameCount: 0,
      sourceProfileId: sourceProfileId,
      stopReason: '',
      importBatchId: '',
      lastFrameSequence: 0,
      runtimeErrorCode: 0
    };
    this.store.createSession(session);

    session.status = CaptureSessionStatus.WAITING_PERMISSION;
    this.store.updateSession(session);
    this.lastSignature = [];
    this.signatureSessionId = session.id;
    runtime.clearLatestFrame();

    let startCode = runtime.startCapture();
    if (startCode !== 0) {
      session.status = CaptureSessionStatus.CANCELLED;
      session.stoppedAtEpochMs = Date.now();
      session.stopReason = CaptureStopReason.START_REJECTED;
      session.runtimeErrorCode = startCode;
      this.store.updateSession(session);
    }
    return session;
  }

  async sampleLatestFrame(): Promise<CaptureSession | null> {
    if (this.sampleInFlight !== null) return await this.sampleInFlight;
    this.sampleInFlight = this.sampleLatestFrameInternal();
    try {
      return await this.sampleInFlight;
    } finally {
      this.sampleInFlight = null;
    }
  }

  private async sampleLatestFrameInternal(): Promise<CaptureSession | null> {
    let session = this.store.getActiveSession();
    if (session === null) return null;
    if (session.status !== CaptureSessionStatus.WAITING_PERMISSION &&
      session.status !== CaptureSessionStatus.CAPTURING &&
      session.status !== CaptureSessionStatus.STOPPING) return session;

    let runtime = this.requireRuntime();
    let stats = runtime.getStats();
    session.frameCount = stats.callbackCount;
    session.runtimeErrorCode = stats.lastError;

    if (session.status === CaptureSessionStatus.WAITING_PERMISSION &&
      (stats.lastError !== 0 || !stats.isCapturing)) {
      runtime.stopCapture();
      runtime.clearLatestFrame();
      session.status = CaptureSessionStatus.CANCELLED;
      session.stoppedAtEpochMs = Date.now();
      session.stopReason = CaptureStopReason.START_REJECTED;
      this.store.updateSession(session);
      return session;
    }

    let runtimeEnded = session.status === CaptureSessionStatus.CAPTURING && !stats.isCapturing;
    let frame = runtime.getLatestFrame();
    if (!frame || frame.sequence <= session.lastFrameSequence) {
      this.store.updateSession(session);
      return runtimeEnded ? this.finishRuntimeEnded(session, stats.lastError) : session;
    }

    if (session.status === CaptureSessionStatus.WAITING_PERMISSION) {
      // The first real video frame is the authorization proof. WAITING_PERMISSION never
      // transitions to CAPTURING merely because startCapture() returned zero.
      session.status = CaptureSessionStatus.CAPTURING;
    }

    session.lastFrameSequence = frame.sequence;
    let signature = this.frameSignature(frame);
    if (!this.isMeaningfulChange(session.id, signature)) {
      this.store.updateSession(session);
      return runtimeEnded ? this.finishRuntimeEnded(session, stats.lastError) : session;
    }

    session.acceptedFrameCount++;
    this.lastSignature = signature;
    this.signatureSessionId = session.id;

    try {
      let recognized = await this.requireRecognizer().recognize(frame);
      let latest = this.store.getSession(session.id);
      if (latest === null || this.isTerminal(latest.status)) return latest;
      if (recognized.text.length > 0) {
        let orderNo = this.store.getEvidence(session.id).length + 1;
        this.store.appendEvidence({
          id: `${session.id}-frame-${frame.sequence}`,
          sessionId: session.id,
          sequence: frame.sequence,
          capturedAtEpochMs: Date.now(),
          runtimeTimestamp: frame.timestamp,
          width: frame.width,
          height: frame.height,
          fingerprint: this.signatureText(signature),
          text: recognized.text,
          lineCount: recognized.lineCount,
          orderNo: orderNo
        });
      }
    } catch {
      // A single OCR failure must not abort a 60-second capture session.
      // Later changed frames remain eligible for recognition.
    }

    this.store.updateSession(session);
    return runtimeEnded ? this.finishRuntimeEnded(session, stats.lastError) : session;
  }

  private finishRuntimeEnded(session: CaptureSession, runtimeErrorCode: number): CaptureSession {
    let runtime = this.requireRuntime();
    try {
      runtime.stopCapture();
    } catch {
      // Runtime may already be stopped by the system; release remains best-effort.
    }
    let batchId = this.ensureImportBatch(session);
    runtime.clearLatestFrame();

    session.importBatchId = batchId;
    session.stoppedAtEpochMs = Date.now();
    session.runtimeErrorCode = runtimeErrorCode;
    if (runtimeErrorCode === 0) {
      session.status = CaptureSessionStatus.COMPLETED;
      session.stopReason = CaptureStopReason.SYSTEM_STOPPED;
    } else {
      session.status = CaptureSessionStatus.FAILED;
      session.stopReason = CaptureStopReason.NATIVE_ERROR;
    }
    this.store.updateSession(session);
    this.lastSignature = [];
    this.signatureSessionId = '';
    return session;
  }

  async stopByUser(): Promise<CaptureSession | null> {
    if (this.sampleInFlight !== null) await this.sampleInFlight;
    let session = this.store.getActiveSession();
    if (session === null) return null;

    let runtime = this.requireRuntime();
    if (session.status === CaptureSessionStatus.WAITING_PERMISSION) {
      runtime.stopCapture();
      session.status = CaptureSessionStatus.CANCELLED;
      session.stoppedAtEpochMs = Date.now();
      session.stopReason = CaptureStopReason.CANCELLED;
      this.store.updateSession(session);
      return session;
    }

    if (session.status !== CaptureSessionStatus.CAPTURING &&
      session.status !== CaptureSessionStatus.STOPPING) return session;

    session.status = CaptureSessionStatus.STOPPING;
    this.store.updateSession(session);

    let stopCode = runtime.stopCapture();
    await this.sampleLatestFrame();
    session = this.store.getSession(session.id) as CaptureSession;
    let batchId = this.ensureImportBatch(session);
    runtime.clearLatestFrame();

    session.importBatchId = batchId;
    session.stoppedAtEpochMs = Date.now();
    session.runtimeErrorCode = stopCode;
    if (stopCode === 0) {
      session.status = CaptureSessionStatus.COMPLETED;
      session.stopReason = CaptureStopReason.USER;
    } else {
      session.status = CaptureSessionStatus.FAILED;
      session.stopReason = CaptureStopReason.NATIVE_ERROR;
    }
    this.store.updateSession(session);
    this.lastSignature = [];
    this.signatureSessionId = '';
    return session;
  }

  async cancel(): Promise<CaptureSession | null> {
    if (this.sampleInFlight !== null) await this.sampleInFlight;
    let session = this.store.getActiveSession();
    if (session === null) return null;
    try {
      let runtime = this.requireRuntime();
      runtime.stopCapture();
      runtime.clearLatestFrame();
    } catch {
      // Cancellation is still terminal even if the native runtime already stopped.
    }
    session.status = CaptureSessionStatus.CANCELLED;
    session.stoppedAtEpochMs = Date.now();
    session.stopReason = CaptureStopReason.CANCELLED;
    this.store.updateSession(session);
    this.lastSignature = [];
    this.signatureSessionId = '';
    return session;
  }

  handleAbilityDestroy(): void {
    let session = this.store.getActiveSession();
    if (session === null) return;
    try {
      let runtime = this.requireRuntime();
      runtime.stopCapture();
      runtime.clearLatestFrame();
    } catch {
      // Destruction recovery must not throw from UIAbility lifecycle.
    }
    session.status = CaptureSessionStatus.FAILED;
    session.stoppedAtEpochMs = Date.now();
    session.stopReason = CaptureStopReason.ABILITY_DESTROYED;
    this.store.updateSession(session);
    this.lastSignature = [];
    this.signatureSessionId = '';
  }

  async release(): Promise<void> {
    let recognizer = this.recognizer;
    if (recognizer !== null) await recognizer.release();
  }

  private ensureImportBatch(session: CaptureSession): string {
    if (session.importBatchId.length > 0) return session.importBatchId;
    let batchId = `capture-batch-${session.id}`;
    let existing = HomeworkImportInboxService.instance.getBatch(batchId);
    if (existing !== null) return batchId;

    let evidence = this.store.getEvidence(session.id);
    let messages: ImportedMessage[] = [];
    for (let item of evidence) {
      let messageId = `${batchId}-message-${item.orderNo}`;
      messages.push({
        id: messageId,
        batchId: batchId,
        sender: '',
        timestampEpochMs: item.capturedAtEpochMs,
        text: item.text,
        attachments: [],
        sourceEvidence: {
          sourceType: HomeworkImportSourceType.SCREEN_CAPTURE,
          sourceMessageIds: [messageId],
          rawText: item.text,
          imageRef: '',
          capturedAtEpochMs: item.capturedAtEpochMs
        },
        fingerprint: item.fingerprint,
        orderNo: item.orderNo
      });
    }

    let batch: ImportBatch = {
      id: batchId,
      studentId: session.studentId,
      sourceType: HomeworkImportSourceType.SCREEN_CAPTURE,
      sourceLabel: session.sourceProfileId === 'issue244-fixture' ? '#244 离线 Fixture' : '屏幕智能采集',
      sourceProfileId: session.sourceProfileId,
      captureSessionId: session.id,
      createdAtEpochMs: session.startedAtEpochMs,
      status: ImportBatchStatus.RECEIVED,
      messageCount: messages.length,
      candidateCount: 0
    };
    HomeworkImportInboxService.instance.importBatch(batch, messages, []);
    return batchId;
  }

  private frameSignature(frame: CaptureFrame): number[] {
    let bytes = new Uint8Array(frame.data);
    if (bytes.length === 0) return [];
    let signature: number[] = [];
    let stride = Math.floor(bytes.length / SIGNATURE_SAMPLES);
    if (stride < 1) stride = 1;
    for (let i = 0; i < bytes.length && signature.length < SIGNATURE_SAMPLES; i += stride) {
      signature.push(bytes[i]);
    }
    return signature;
  }

  private isMeaningfulChange(sessionId: string, signature: number[]): boolean {
    if (signature.length === 0) return false;
    if (this.signatureSessionId !== sessionId || this.lastSignature.length !== signature.length) return true;
    let total = 0;
    for (let i = 0; i < signature.length; i++) {
      total += Math.abs(signature[i] - this.lastSignature[i]);
    }
    return total / signature.length >= FRAME_DIFF_THRESHOLD;
  }

  private signatureText(signature: number[]): string {
    let result = '';
    for (let i = 0; i < signature.length; i += 8) {
      if (result.length > 0) result += '-';
      result += signature[i].toString(16);
    }
    return result;
  }

  private isTerminal(status: CaptureSessionStatus): boolean {
    return status === CaptureSessionStatus.COMPLETED ||
      status === CaptureSessionStatus.CANCELLED ||
      status === CaptureSessionStatus.FAILED;
  }

  private requireRuntime(): HomeworkCaptureRuntime {
    if (this.runtime === null) throw new Error('屏幕采集运行时尚未初始化');
    return this.runtime;
  }

  private requireRecognizer(): HomeworkCaptureFrameRecognizer {
    if (this.recognizer === null) throw new Error('采集 OCR 尚未初始化');
    return this.recognizer;
  }
}
