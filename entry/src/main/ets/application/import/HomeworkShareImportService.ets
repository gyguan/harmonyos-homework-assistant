import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { HomeworkImportInboxService } from './HomeworkImportInboxService';
import { HomeworkImportService } from './HomeworkImportService';
import { DefaultHomeworkImportDraftRepository } from '../../data/repository/DefaultHomeworkImportDraftRepository';
import {
  HomeworkImportSourceType,
  ImportBatch,
  ImportBatchStatus,
  ImportedMessage
} from '../../domain/model/ImportModels';
import {
  HomeworkShareImportProcessResult,
  HomeworkShareRecordKind,
  PendingHomeworkShareImport,
  PendingHomeworkShareRecord
} from '../../domain/model/HomeworkShareModels';
import {
  CandidateAssignment,
  HomeworkImportSourceKind,
  RawHomeworkImport
} from '../../domain/model/HomeworkModels';
import { PreferencesHomeworkShareHandoffPersistence } from '../../infrastructure/persistence/PreferencesHomeworkShareHandoffPersistence';

export class HomeworkShareImportService {
  static readonly instance: HomeworkShareImportService = new HomeworkShareImportService();

  private context: common.Context | null = null;
  private constructor() {}

  configure(context: common.Context): void {
    this.context = context;
  }

  async process(token: string): Promise<HomeworkShareImportProcessResult> {
    let context = this.requireContext();
    let persistence = new PreferencesHomeworkShareHandoffPersistence(context);
    let pending = await persistence.find(token);
    if (pending === null) throw new Error('找不到这次系统分享，请重新分享');

    let batchId = `import-${pending.token}`;
    let existing = HomeworkImportInboxService.instance.getBatch(batchId);
    if (existing !== null) {
      if (existing.status === ImportBatchStatus.READY) {
        HomeworkImportInboxService.instance.activateBatch(batchId);
      }
      await persistence.remove(token);
      return { batchId: batchId, candidateCount: existing.candidateCount };
    }

    let studentId = DefaultHomeworkImportDraftRepository.instance.getActiveStudentId();
    let messages: ImportedMessage[] = [];
    let candidates: CandidateAssignment[] = [];

    // Do not persist an ImportBatch until every shared record has been extracted and parsed.
    // This preserves the #243 all-or-nothing retry contract for OCR failures.
    for (let i = 0; i < pending.records.length; i++) {
      let record = pending.records[i];
      let rawImport = this.rawImport(pending, record, studentId, i + 1);
      let output = await HomeworkImportService.instance.parseImportedSource(rawImport);
      let message = this.message(pending, record, output.extracted.text, i + 1);
      messages.push(message);
      for (let candidate of output.candidates) {
        candidates.push(this.withMessageEvidence(candidate, batchId, message, record));
      }
    }

    let batch: ImportBatch = {
      id: batchId,
      studentId: studentId,
      sourceType: HomeworkImportSourceType.SHARE,
      sourceLabel: '系统分享',
      createdAtEpochMs: pending.createdAtEpochMs,
      status: candidates.length > 0 ? ImportBatchStatus.READY : ImportBatchStatus.EMPTY,
      messageCount: messages.length,
      candidateCount: candidates.length
    };

    HomeworkImportInboxService.instance.importBatch(batch, messages, candidates);
    if (candidates.length > 0) {
      HomeworkImportInboxService.instance.activateBatch(batchId);
    }
    await persistence.remove(token);
    return { batchId: batchId, candidateCount: candidates.length };
  }

  async cancel(token: string): Promise<void> {
    let context = this.requireContext();
    let persistence = new PreferencesHomeworkShareHandoffPersistence(context);
    let pending = await persistence.find(token);
    if (pending !== null) this.cleanupPendingFiles(pending);
    await persistence.remove(token);
  }

  private rawImport(pending: PendingHomeworkShareImport, record: PendingHomeworkShareRecord,
    studentId: string, orderNo: number): RawHomeworkImport {
    return {
      id: `${pending.token}-source-${orderNo}`,
      studentId: studentId,
      sourceKind: HomeworkImportSourceKind.SHARE,
      sourceLabel: record.title.length > 0 ? `系统分享 · ${record.title}` : '系统分享',
      resourceUri: record.kind === HomeworkShareRecordKind.IMAGE ? record.sandboxUri : '',
      rawText: record.kind === HomeworkShareRecordKind.TEXT ? record.content : ''
    };
  }

  private message(pending: PendingHomeworkShareImport, record: PendingHomeworkShareRecord,
    extractedText: string, orderNo: number): ImportedMessage {
    return {
      id: record.id,
      batchId: `import-${pending.token}`,
      sender: '',
      timestampEpochMs: pending.createdAtEpochMs,
      text: extractedText,
      attachments: record.sandboxUri.length > 0 ? [record.sandboxUri] : [],
      sourceEvidence: {
        sourceType: HomeworkImportSourceType.SHARE,
        sourceMessageIds: [record.id],
        rawText: record.kind === HomeworkShareRecordKind.TEXT ? record.content : extractedText,
        imageRef: record.sandboxUri,
        capturedAtEpochMs: pending.createdAtEpochMs
      },
      fingerprint: this.fingerprint(record, extractedText),
      orderNo: orderNo
    };
  }

  private withMessageEvidence(candidate: CandidateAssignment, batchId: string,
    message: ImportedMessage, record: PendingHomeworkShareRecord): CandidateAssignment {
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
        sourceType: HomeworkImportSourceType.SHARE,
        sourceMessageIds: [message.id],
        rawText: message.text,
        imageRef: record.sandboxUri,
        capturedAtEpochMs: message.timestampEpochMs
      },
      confidence: candidate.confidence
    };
  }

  private fingerprint(record: PendingHomeworkShareRecord, extractedText: string): string {
    let value = record.kind === HomeworkShareRecordKind.TEXT ? record.content : extractedText;
    let normalized = value.trim().split('\r').join('').split('\n').join(' ');
    return `${record.kind}:${normalized.length}:${normalized.substring(0, 64)}:${record.sandboxUri}`;
  }

  private cleanupPendingFiles(pending: PendingHomeworkShareImport): void {
    for (let record of pending.records) {
      if (record.sandboxUri.length === 0) continue;
      try {
        fileIo.unlinkSync(record.sandboxUri);
      } catch {
        // Cancellation cleanup is best-effort; no ImportBatch or Assignment is created.
      }
    }
  }

  private requireContext(): common.Context {
    if (this.context === null) throw new Error('系统分享导入能力尚未初始化');
    return this.context;
  }
}
