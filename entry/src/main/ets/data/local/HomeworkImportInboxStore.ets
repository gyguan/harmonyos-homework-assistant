import {
  HomeworkImportInboxSnapshot,
  ImportBatch,
  ImportBatchStatus,
  ImportedMessage
} from '../../domain/model/ImportModels';
import { CandidateAssignment } from '../../domain/model/HomeworkModels';
import { HomeworkImportInboxPersistence } from '../../domain/port/HomeworkImportInboxPersistence';

const INBOX_SCHEMA_VERSION: number = 1;

export class HomeworkImportInboxStore {
  static readonly instance: HomeworkImportInboxStore = new HomeworkImportInboxStore();

  private activeBatchId: string = '';
  private batches: ImportBatch[] = [];
  private messages: ImportedMessage[] = [];
  private candidates: CandidateAssignment[] = [];
  private persistence: HomeworkImportInboxPersistence | null = null;
  private persistRequested: boolean = false;
  private persistRunning: boolean = false;

  private constructor() {}

  async initialize(persistence: HomeworkImportInboxPersistence): Promise<void> {
    this.persistence = persistence;
    let snapshot = await persistence.load();
    if (snapshot === null) {
      await persistence.save(this.createSnapshot());
      return;
    }
    if (snapshot.schemaVersion !== INBOX_SCHEMA_VERSION) {
      throw new Error(`不支持的作业导入收件箱版本: ${snapshot.schemaVersion}`);
    }
    this.restore(snapshot);
  }

  private restore(snapshot: HomeworkImportInboxSnapshot): void {
    this.activeBatchId = snapshot.activeBatchId;
    this.batches = [];
    this.messages = [];
    this.candidates = [];
    for (let batch of snapshot.batches) this.batches.push(this.cloneBatch(batch));
    for (let message of snapshot.messages) this.messages.push(this.cloneMessage(message));
    for (let candidate of snapshot.candidates) this.candidates.push(this.cloneCandidate(candidate));
  }

  private createSnapshot(): HomeworkImportInboxSnapshot {
    let batches: ImportBatch[] = [];
    let messages: ImportedMessage[] = [];
    let candidates: CandidateAssignment[] = [];
    for (let batch of this.batches) batches.push(this.cloneBatch(batch));
    for (let message of this.messages) messages.push(this.cloneMessage(message));
    for (let candidate of this.candidates) candidates.push(this.cloneCandidate(candidate));
    return {
      schemaVersion: INBOX_SCHEMA_VERSION,
      activeBatchId: this.activeBatchId,
      batches: batches,
      messages: messages,
      candidates: candidates
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
      await persistence.save(this.createSnapshot());
    }
    this.persistRunning = false;
  }

  private cloneBatch(source: ImportBatch): ImportBatch {
    return {
      id: source.id,
      studentId: source.studentId,
      sourceType: source.sourceType,
      sourceLabel: source.sourceLabel,
      sourceProfileId: source.sourceProfileId,
      captureSessionId: source.captureSessionId,
      reconstructed: source.reconstructed,
      groupTitle: source.groupTitle,
      timeBoundaryReached: source.timeBoundaryReached,
      earliestDetectedTime: source.earliestDetectedTime,
      reconstructionWarnings: source.reconstructionWarnings === undefined ?
        undefined : source.reconstructionWarnings.slice(),
      understood: source.understood,
      pendingReviewMessageIds: source.pendingReviewMessageIds === undefined ?
        undefined : source.pendingReviewMessageIds.slice(),
      understandingWarnings: source.understandingWarnings === undefined ?
        undefined : source.understandingWarnings.slice(),
      classificationSummary: source.classificationSummary,
      createdAtEpochMs: source.createdAtEpochMs,
      status: source.status,
      messageCount: source.messageCount,
      candidateCount: source.candidateCount
    };
  }

  private cloneMessage(source: ImportedMessage): ImportedMessage {
    return {
      id: source.id,
      batchId: source.batchId,
      sender: source.sender,
      timestampEpochMs: source.timestampEpochMs,
      text: source.text,
      attachments: source.attachments.slice(),
      sourceEvidence: {
        sourceType: source.sourceEvidence.sourceType,
        sourceMessageIds: source.sourceEvidence.sourceMessageIds.slice(),
        sourceFrameEvidenceIds: source.sourceEvidence.sourceFrameEvidenceIds === undefined ?
          undefined : source.sourceEvidence.sourceFrameEvidenceIds.slice(),
        rawText: source.sourceEvidence.rawText,
        imageRef: source.sourceEvidence.imageRef,
        capturedAtEpochMs: source.sourceEvidence.capturedAtEpochMs
      },
      fingerprint: source.fingerprint,
      orderNo: source.orderNo
    };
  }

  private cloneCandidate(source: CandidateAssignment): CandidateAssignment {
    return {
      id: source.id,
      studentId: source.studentId,
      subject: source.subject,
      title: source.title,
      instruction: source.instruction,
      textbookRef: source.textbookRef,
      dueText: source.dueText,
      expectedMinutes: source.expectedMinutes,
      sourceEvidence: {
        sourceLabel: source.sourceEvidence.sourceLabel,
        excerpt: source.sourceEvidence.excerpt,
        batchId: source.sourceEvidence.batchId,
        sourceType: source.sourceEvidence.sourceType,
        sourceMessageIds: source.sourceEvidence.sourceMessageIds === undefined ?
          undefined : source.sourceEvidence.sourceMessageIds.slice(),
        rawText: source.sourceEvidence.rawText,
        imageRef: source.sourceEvidence.imageRef,
        capturedAtEpochMs: source.sourceEvidence.capturedAtEpochMs
      },
      confidence: source.confidence
    };
  }

  private batchIndex(batchId: string): number {
    for (let i = 0; i < this.batches.length; i++) if (this.batches[i].id === batchId) return i;
    return -1;
  }

  private candidateBelongsTo(candidate: CandidateAssignment, batchId: string): boolean {
    return candidate.sourceEvidence.batchId === batchId;
  }

  listBatches(studentId: string): ImportBatch[] {
    let result: ImportBatch[] = [];
    for (let batch of this.batches) {
      if (batch.studentId === studentId) result.push(this.cloneBatch(batch));
    }
    result.sort((left: ImportBatch, right: ImportBatch) => right.createdAtEpochMs - left.createdAtEpochMs);
    return result;
  }

  getBatch(batchId: string): ImportBatch | null {
    let index = this.batchIndex(batchId);
    return index >= 0 ? this.cloneBatch(this.batches[index]) : null;
  }

  getMessages(batchId: string): ImportedMessage[] {
    let result: ImportedMessage[] = [];
    for (let message of this.messages) {
      if (message.batchId === batchId) result.push(this.cloneMessage(message));
    }
    result.sort((left: ImportedMessage, right: ImportedMessage) => left.orderNo - right.orderNo);
    return result;
  }

  getCandidates(batchId: string): CandidateAssignment[] {
    let result: CandidateAssignment[] = [];
    for (let candidate of this.candidates) {
      if (this.candidateBelongsTo(candidate, batchId)) result.push(this.cloneCandidate(candidate));
    }
    return result;
  }

  getActiveBatchId(): string { return this.activeBatchId; }

  saveBatch(batch: ImportBatch, messages: ImportedMessage[], candidates: CandidateAssignment[]): void {
    let index = this.batchIndex(batch.id);
    if (index >= 0) this.batches[index] = this.cloneBatch(batch);
    else this.batches.push(this.cloneBatch(batch));

    let retainedMessages: ImportedMessage[] = [];
    for (let existing of this.messages) if (existing.batchId !== batch.id) retainedMessages.push(existing);
    for (let message of messages) retainedMessages.push(this.cloneMessage(message));
    this.messages = retainedMessages;

    this.replaceBatchCandidates(batch.id, candidates);
    this.requestPersist();
  }

  private replaceBatchCandidates(batchId: string, candidates: CandidateAssignment[]): void {
    let retained: CandidateAssignment[] = [];
    for (let existing of this.candidates) {
      if (!this.candidateBelongsTo(existing, batchId)) retained.push(existing);
    }
    for (let candidate of candidates) retained.push(this.cloneCandidate(candidate));
    this.candidates = retained;

    let index = this.batchIndex(batchId);
    if (index >= 0) this.batches[index].candidateCount = candidates.length;
  }

  setActiveBatch(batchId: string): boolean {
    if (this.batchIndex(batchId) < 0) return false;
    this.activeBatchId = batchId;
    this.requestPersist();
    return true;
  }

  syncCandidates(batchId: string, candidates: CandidateAssignment[]): void {
    if (batchId.length === 0 || this.batchIndex(batchId) < 0) return;
    this.replaceBatchCandidates(batchId, candidates);
    this.requestPersist();
  }

  markPublished(batchId: string): boolean {
    let index = this.batchIndex(batchId);
    if (index < 0) return false;
    this.batches[index].status = ImportBatchStatus.PUBLISHED;
    if (this.activeBatchId === batchId) this.activeBatchId = '';
    this.requestPersist();
    return true;
  }

  abandon(batchId: string): boolean {
    let index = this.batchIndex(batchId);
    if (index < 0 || this.batches[index].status === ImportBatchStatus.PUBLISHED) return false;
    this.batches[index].status = ImportBatchStatus.ABANDONED;
    if (this.activeBatchId === batchId) this.activeBatchId = '';
    this.requestPersist();
    return true;
  }
}
