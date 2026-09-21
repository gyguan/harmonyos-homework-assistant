import {
  CaptureFrameEvidence,
  CaptureSession,
  CaptureSessionStatus,
  CaptureStopReason,
  HomeworkCaptureSessionSnapshot
} from '../../domain/model/CaptureModels';
import { HomeworkCaptureSessionPersistence } from '../../domain/port/HomeworkCaptureSessionPersistence';

const CAPTURE_SCHEMA_VERSION: number = 1;

export class HomeworkCaptureSessionStore {
  static readonly instance: HomeworkCaptureSessionStore = new HomeworkCaptureSessionStore();

  private activeSessionId: string = '';
  private sessions: CaptureSession[] = [];
  private evidence: CaptureFrameEvidence[] = [];
  private persistence: HomeworkCaptureSessionPersistence | null = null;
  private persistRequested: boolean = false;
  private persistRunning: boolean = false;

  private constructor() {}

  async initialize(persistence: HomeworkCaptureSessionPersistence): Promise<void> {
    this.persistence = persistence;
    let snapshot = await persistence.load();
    if (snapshot === null) {
      await persistence.save(this.snapshot());
      return;
    }
    if (snapshot.schemaVersion !== CAPTURE_SCHEMA_VERSION) {
      throw new Error(`不支持的采集会话版本: ${snapshot.schemaVersion}`);
    }
    this.restore(snapshot);
    if (this.recoverInterruptedSession()) this.requestPersist();
  }

  private restore(snapshot: HomeworkCaptureSessionSnapshot): void {
    this.activeSessionId = snapshot.activeSessionId;
    this.sessions = [];
    this.evidence = [];
    for (let item of snapshot.sessions) this.sessions.push(this.cloneSession(item));
    for (let item of snapshot.evidence) this.evidence.push(this.cloneEvidence(item));
  }

  private recoverInterruptedSession(): boolean {
    if (this.activeSessionId.length === 0) return false;
    let index = this.sessionIndex(this.activeSessionId);
    if (index < 0) {
      this.activeSessionId = '';
      return true;
    }
    let status = this.sessions[index].status;
    if (status === CaptureSessionStatus.CREATED ||
      status === CaptureSessionStatus.WAITING_PERMISSION ||
      status === CaptureSessionStatus.CAPTURING ||
      status === CaptureSessionStatus.STOPPING) {
      this.sessions[index].status = CaptureSessionStatus.FAILED;
      this.sessions[index].stoppedAtEpochMs = Date.now();
      this.sessions[index].stopReason = CaptureStopReason.PROCESS_RESTARTED;
      this.activeSessionId = '';
      return true;
    }
    this.activeSessionId = '';
    return true;
  }

  private snapshot(): HomeworkCaptureSessionSnapshot {
    let sessions: CaptureSession[] = [];
    let evidence: CaptureFrameEvidence[] = [];
    for (let item of this.sessions) sessions.push(this.cloneSession(item));
    for (let item of this.evidence) evidence.push(this.cloneEvidence(item));
    return {
      schemaVersion: CAPTURE_SCHEMA_VERSION,
      activeSessionId: this.activeSessionId,
      sessions: sessions,
      evidence: evidence
    };
  }

  private requestPersist(): void {
    if (this.persistence === null) return;
    this.persistRequested = true;
    if (!this.persistRunning) void this.flushPersistQueue();
  }

  private async flushPersistQueue(): Promise<void> {
    let persistence = this.persistence;
    if (persistence === null || this.persistRunning) return;
    this.persistRunning = true;
    while (this.persistRequested) {
      this.persistRequested = false;
      await persistence.save(this.snapshot());
    }
    this.persistRunning = false;
  }

  private cloneSession(source: CaptureSession): CaptureSession {
    return {
      id: source.id,
      studentId: source.studentId,
      startedAtEpochMs: source.startedAtEpochMs,
      stoppedAtEpochMs: source.stoppedAtEpochMs,
      status: source.status,
      frameCount: source.frameCount,
      acceptedFrameCount: source.acceptedFrameCount,
      sourceProfileId: source.sourceProfileId,
      stopReason: source.stopReason,
      importBatchId: source.importBatchId,
      lastFrameSequence: source.lastFrameSequence,
      runtimeErrorCode: source.runtimeErrorCode
    };
  }

  private cloneEvidence(source: CaptureFrameEvidence): CaptureFrameEvidence {
    return {
      id: source.id,
      sessionId: source.sessionId,
      sequence: source.sequence,
      capturedAtEpochMs: source.capturedAtEpochMs,
      width: source.width,
      height: source.height,
      fingerprint: source.fingerprint,
      text: source.text,
      lineCount: source.lineCount,
      orderNo: source.orderNo
    };
  }

  private sessionIndex(sessionId: string): number {
    for (let i = 0; i < this.sessions.length; i++) {
      if (this.sessions[i].id === sessionId) return i;
    }
    return -1;
  }

  getActiveSession(): CaptureSession | null {
    if (this.activeSessionId.length === 0) return null;
    return this.getSession(this.activeSessionId);
  }

  getSession(sessionId: string): CaptureSession | null {
    let index = this.sessionIndex(sessionId);
    return index < 0 ? null : this.cloneSession(this.sessions[index]);
  }

  listSessions(studentId: string): CaptureSession[] {
    let result: CaptureSession[] = [];
    for (let item of this.sessions) {
      if (item.studentId === studentId) result.push(this.cloneSession(item));
    }
    result.sort((a: CaptureSession, b: CaptureSession) => b.startedAtEpochMs - a.startedAtEpochMs);
    return result;
  }

  getEvidence(sessionId: string): CaptureFrameEvidence[] {
    let result: CaptureFrameEvidence[] = [];
    for (let item of this.evidence) {
      if (item.sessionId === sessionId) result.push(this.cloneEvidence(item));
    }
    result.sort((a: CaptureFrameEvidence, b: CaptureFrameEvidence) => a.orderNo - b.orderNo);
    return result;
  }

  createSession(session: CaptureSession): void {
    if (this.activeSessionId.length > 0) {
      throw new Error('已有采集会话正在运行');
    }
    this.sessions.push(this.cloneSession(session));
    this.activeSessionId = session.id;
    this.requestPersist();
  }

  updateSession(session: CaptureSession): void {
    let index = this.sessionIndex(session.id);
    if (index < 0) throw new Error('采集会话不存在');
    this.sessions[index] = this.cloneSession(session);
    if (this.isTerminal(session.status) && this.activeSessionId === session.id) {
      this.activeSessionId = '';
    }
    this.requestPersist();
  }

  appendEvidence(item: CaptureFrameEvidence): void {
    for (let existing of this.evidence) {
      if (existing.id === item.id) return;
    }
    this.evidence.push(this.cloneEvidence(item));
    this.requestPersist();
  }

  private isTerminal(status: CaptureSessionStatus): boolean {
    return status === CaptureSessionStatus.COMPLETED ||
      status === CaptureSessionStatus.CANCELLED ||
      status === CaptureSessionStatus.FAILED;
  }
}
