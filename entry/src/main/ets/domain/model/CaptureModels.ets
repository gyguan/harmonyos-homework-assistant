export enum CaptureSessionStatus {
  CREATED = 'CREATED',
  WAITING_PERMISSION = 'WAITING_PERMISSION',
  CAPTURING = 'CAPTURING',
  STOPPING = 'STOPPING',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
  FAILED = 'FAILED'
}

export enum CaptureStopReason {
  USER = 'USER',
  START_REJECTED = 'START_REJECTED',
  SYSTEM_STOPPED = 'SYSTEM_STOPPED',
  NATIVE_ERROR = 'NATIVE_ERROR',
  ABILITY_DESTROYED = 'ABILITY_DESTROYED',
  PROCESS_RESTARTED = 'PROCESS_RESTARTED',
  FIRST_FRAME_TIMEOUT = 'FIRST_FRAME_TIMEOUT',
  CANCELLED = 'CANCELLED'
}

export interface CaptureFrame {
  data: ArrayBuffer;
  width: number;
  height: number;
  timestamp: number;
  sequence: number;
}

export interface CaptureRuntimeStats {
  isCapturing: boolean;
  lastError: number;
  state?: number;
  callbackCount: number;
  sampledFrameCount: number;
  latestSequence: number;
  latestWidth?: number;
  latestHeight?: number;
  pendingFrameCount?: number;
}

export interface CaptureOcrLineEvidence {
  value: string;
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface CaptureFrameRecognition {
  text: string;
  lineCount: number;
  lines: CaptureOcrLineEvidence[];
}

export interface CaptureFrameEvidence {
  id: string;
  sessionId: string;
  sequence: number;
  capturedAtEpochMs: number;
  runtimeTimestamp: number;
  width: number;
  height: number;
  fingerprint: string;
  text: string;
  lineCount: number;
  lines?: CaptureOcrLineEvidence[];
  orderNo: number;
}

export interface CaptureSession {
  id: string;
  studentId: string;
  startedAtEpochMs: number;
  stoppedAtEpochMs: number;
  status: CaptureSessionStatus;
  frameCount: number;
  acceptedFrameCount: number;
  ocrFailureCount: number;
  sourceProfileId: string;
  stopReason: string;
  importBatchId: string;
  lastFrameSequence: number;
  runtimeErrorCode: number;
}

export interface HomeworkCaptureSessionSnapshot {
  schemaVersion: number;
  activeSessionId: string;
  sessions: CaptureSession[];
  evidence: CaptureFrameEvidence[];
}
