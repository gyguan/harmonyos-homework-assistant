import { DefaultHomeworkImportInboxRepository } from '../../data/repository/DefaultHomeworkImportInboxRepository';
import { DefaultHomeworkImportDraftRepository } from '../../data/repository/DefaultHomeworkImportDraftRepository';
import {
  ImportBatch,
  ImportBatchStatus,
  ImportedMessage,
  HomeworkImportSourceType
} from '../../domain/model/ImportModels';
import {
  CandidateAssignment,
  HomeworkImportSourceKind,
  RawHomeworkImport
} from '../../domain/model/HomeworkModels';
import { HomeworkImportInboxRepository } from '../../domain/port/HomeworkImportInboxRepository';
import { HomeworkImportDraftRepository } from '../../domain/port/HomeworkImportDraftRepository';

export class HomeworkImportInboxService {
  static readonly instance: HomeworkImportInboxService = new HomeworkImportInboxService();

  private readonly inbox: HomeworkImportInboxRepository = DefaultHomeworkImportInboxRepository.instance;
  private readonly drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance;

  private constructor() {}

  listBatches(studentId: string): ImportBatch[] {
    return this.inbox.listBatches(studentId);
  }

  getBatch(batchId: string): ImportBatch | null {
    return this.inbox.getBatch(batchId);
  }

  getMessages(batchId: string): ImportedMessage[] {
    return this.inbox.getMessages(batchId);
  }

  getCandidates(batchId: string): CandidateAssignment[] {
    return this.inbox.getCandidates(batchId);
  }

  commitParsedImport(rawImport: RawHomeworkImport, sourceType: HomeworkImportSourceType,
    extractedText: string, candidates: CandidateAssignment[], imageRef: string = ''): void {
    let batchId = rawImport.id;
    let messageId = `${batchId}-message-1`;
    let createdAt = this.timestampFromId(batchId);
    let message: ImportedMessage = {
      id: messageId,
      batchId: batchId,
      sender: '',
      timestampEpochMs: createdAt,
      text: extractedText,
      attachments: imageRef.length > 0 ? [imageRef] : [],
      sourceEvidence: {
        sourceType: sourceType,
        sourceMessageIds: [messageId],
        rawText: extractedText,
        imageRef: imageRef,
        capturedAtEpochMs: createdAt
      },
      fingerprint: this.fingerprint(extractedText, imageRef),
      orderNo: 1
    };

    let enriched: CandidateAssignment[] = [];
    for (let candidate of candidates) {
      enriched.push(this.withEvidence(candidate, batchId, sourceType, message));
    }

    let batch: ImportBatch = {
      id: batchId,
      studentId: rawImport.studentId,
      sourceType: sourceType,
      sourceLabel: rawImport.sourceLabel,
      sourceProfileId: '',
      createdAtEpochMs: createdAt,
      status: enriched.length > 0 ? ImportBatchStatus.READY : ImportBatchStatus.EMPTY,
      messageCount: 1,
      candidateCount: enriched.length
    };
    this.inbox.saveBatch(batch, [message], enriched);

    if (enriched.length === 0) return;
    this.inbox.setActiveBatch(batchId);
    this.drafts.replaceRawImport({
      id: rawImport.id,
      studentId: rawImport.studentId,
      sourceKind: rawImport.sourceKind,
      sourceLabel: rawImport.sourceLabel,
      resourceUri: rawImport.resourceUri,
      rawText: extractedText
    });
    this.drafts.replaceCandidates(enriched);
  }

  importBatch(batch: ImportBatch, messages: ImportedMessage[], candidates: CandidateAssignment[]): void {
    for (let message of messages) {
      if (message.batchId !== batch.id) throw new Error('导入消息不属于当前批次');
    }
    let normalized: CandidateAssignment[] = [];
    for (let candidate of candidates) {
      if (candidate.studentId !== batch.studentId) throw new Error('候选作业不属于当前孩子');
      let sourceIds = candidate.sourceEvidence.sourceMessageIds;
      let messageIds: string[] = sourceIds === undefined ? [] : sourceIds.slice();
      if (messageIds.length === 0 && messages.length > 0) messageIds.push(messages[0].id);
      let rawText = candidate.sourceEvidence.rawText;
      if ((rawText === undefined || rawText.length === 0) && messages.length > 0) rawText = messages[0].text;
      normalized.push({
        id: candidate.id,
        studentId: candidate.studentId,
        subject: candidate.subject,
        title: candidate.title,
        instruction: candidate.instruction,
        textbookRef: candidate.textbookRef,
        dueText: candidate.dueText,
        expectedMinutes: candidate.expectedMinutes,
        sourceEvidence: {
          sourceLabel: candidate.sourceEvidence.sourceLabel,
          excerpt: candidate.sourceEvidence.excerpt,
          batchId: batch.id,
          sourceType: batch.sourceType,
          sourceMessageIds: messageIds,
          rawText: rawText,
          imageRef: candidate.sourceEvidence.imageRef,
          capturedAtEpochMs: candidate.sourceEvidence.capturedAtEpochMs
        },
        confidence: candidate.confidence
      });
    }

    let storedBatch: ImportBatch = {
      id: batch.id,
      studentId: batch.studentId,
      sourceType: batch.sourceType,
      sourceLabel: batch.sourceLabel,
      sourceProfileId: batch.sourceProfileId,
      captureSessionId: batch.captureSessionId,
      reconstructed: batch.reconstructed,
      groupTitle: batch.groupTitle,
      timeBoundaryReached: batch.timeBoundaryReached,
      earliestDetectedTime: batch.earliestDetectedTime,
      reconstructionWarnings: batch.reconstructionWarnings === undefined ?
        undefined : batch.reconstructionWarnings.slice(),
      understood: batch.understood,
      understandingVersion: batch.understandingVersion,
      pendingReviewMessageIds: batch.pendingReviewMessageIds === undefined ?
        undefined : batch.pendingReviewMessageIds.slice(),
      understandingWarnings: batch.understandingWarnings === undefined ?
        undefined : batch.understandingWarnings.slice(),
      classificationSummary: batch.classificationSummary,
      createdAtEpochMs: batch.createdAtEpochMs,
      status: normalized.length > 0 ? ImportBatchStatus.READY :
        (batch.status === ImportBatchStatus.RECEIVED ? ImportBatchStatus.RECEIVED : ImportBatchStatus.EMPTY),
      messageCount: messages.length,
      candidateCount: normalized.length
    };
    this.inbox.saveBatch(storedBatch, messages, normalized);
  }

  activateBatch(batchId: string): boolean {
    let batch = this.inbox.getBatch(batchId);
    if (batch === null || batch.status === ImportBatchStatus.ABANDONED ||
      batch.status === ImportBatchStatus.PUBLISHED ||
      batch.studentId !== this.drafts.getActiveStudentId()) return false;

    let messages = this.inbox.getMessages(batchId);
    let candidates = this.inbox.getCandidates(batchId);
    if (candidates.length === 0) return false;
    if (!this.inbox.setActiveBatch(batchId)) return false;

    let text = '';
    let resourceUri = '';
    for (let message of messages) {
      if (text.length > 0 && message.text.length > 0) text += '\n';
      text += message.text;
      if (resourceUri.length === 0 && message.attachments.length > 0) resourceUri = message.attachments[0];
    }

    this.drafts.replaceRawImport({
      id: batch.id,
      studentId: batch.studentId,
      sourceKind: this.legacySourceKind(batch.sourceType),
      sourceLabel: batch.sourceLabel,
      resourceUri: resourceUri,
      rawText: text
    });
    this.drafts.replaceCandidates(candidates);
    return true;
  }

  abandonBatch(batchId: string): boolean {
    let active = this.inbox.getActiveBatchId();
    let abandoned = this.inbox.abandon(batchId);
    if (!abandoned) return false;
    if (active === batchId) this.drafts.clearCandidates();
    return true;
  }

  markActiveBatchPublished(): void {
    let batchId = this.inbox.getActiveBatchId();
    if (batchId.length > 0) this.inbox.markPublished(batchId);
  }

  private withEvidence(candidate: CandidateAssignment, batchId: string,
    sourceType: HomeworkImportSourceType, message: ImportedMessage): CandidateAssignment {
    return {
      id: candidate.id,
      studentId: candidate.studentId,
      subject: candidate.subject,
      title: candidate.title,
      instruction: candidate.instruction,
      textbookRef: candidate.textbookRef,
      dueText: candidate.dueText,
      expectedMinutes: candidate.expectedMinutes,
      sourceEvidence: {
        sourceLabel: candidate.sourceEvidence.sourceLabel,
        excerpt: candidate.sourceEvidence.excerpt,
        batchId: batchId,
        sourceType: sourceType,
        sourceMessageIds: [message.id],
        rawText: message.text,
        imageRef: message.sourceEvidence.imageRef,
        capturedAtEpochMs: message.sourceEvidence.capturedAtEpochMs
      },
      confidence: candidate.confidence
    };
  }

  private legacySourceKind(sourceType: HomeworkImportSourceType): HomeworkImportSourceKind {
    if (sourceType === HomeworkImportSourceType.SCREENSHOT) return HomeworkImportSourceKind.IMAGE;
    if (sourceType === HomeworkImportSourceType.SHARE) return HomeworkImportSourceKind.SHARE;
    if (sourceType === HomeworkImportSourceType.SCREEN_CAPTURE) return HomeworkImportSourceKind.IMAGE;
    return HomeworkImportSourceKind.TEXT;
  }

  private timestampFromId(value: string): number {
    let parts = value.split('-');
    for (let part of parts) {
      let parsed = Number(part);
      if (part.length === 13 && Number.isFinite(parsed) && parsed > 0) return parsed;
    }
    return Date.now();
  }

  private fingerprint(text: string, imageRef: string): string {
    let normalized = text.trim().split('\r').join('').split('\n').join(' ');
    return `${normalized.length}:${normalized.substring(0, 64)}:${imageRef}`;
  }
}
