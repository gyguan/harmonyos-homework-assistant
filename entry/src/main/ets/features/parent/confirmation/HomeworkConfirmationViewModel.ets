import { HomeworkBatchPublishResult, HomeworkBatchPublishService } from '../../../application/import/HomeworkBatchPublishService';
import { DefaultHomeworkImportDraftRepository } from '../../../data/repository/DefaultHomeworkImportDraftRepository';
import { DefaultHomeworkImportInboxRepository } from '../../../data/repository/DefaultHomeworkImportInboxRepository';
import { CandidateAssignment, RawHomeworkImport, Subject } from '../../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../../domain/port/HomeworkImportDraftRepository';

export class HomeworkConfirmationViewModel {
  private readonly drafts: HomeworkImportDraftRepository;

  constructor(drafts: HomeworkImportDraftRepository = DefaultHomeworkImportDraftRepository.instance) {
    this.drafts = drafts;
  }

  candidates(): CandidateAssignment[] { return this.drafts.getCandidates(); }
  rawImport(): RawHomeworkImport { return this.drafts.getRawImport(); }
  updateCandidate(candidate: CandidateAssignment): boolean { return this.drafts.updateCandidate(candidate); }
  removeCandidate(candidateId: string): boolean { return this.drafts.removeCandidate(candidateId); }

  createManualCandidateDraft(): CandidateAssignment {
    let raw = this.rawImport();
    let inbox = DefaultHomeworkImportInboxRepository.instance;
    let activeBatchId = inbox.getActiveBatchId();
    let sourceMessageIds: string[] = [];
    let capturedAt = Date.now();
    let evidenceText = raw.rawText.trim();

    if (activeBatchId.length > 0) {
      let batch = inbox.getBatch(activeBatchId);
      let messages = inbox.getMessages(activeBatchId);
      if (batch !== null && batch.pendingReviewMessageIds !== undefined &&
        batch.pendingReviewMessageIds.length > 0) {
        sourceMessageIds = batch.pendingReviewMessageIds.slice();
      } else {
        for (let message of messages) sourceMessageIds.push(message.id);
      }
      for (let message of messages) {
        let value = message.sourceEvidence.capturedAtEpochMs;
        if (value > 0 && (capturedAt <= 0 || value < capturedAt)) capturedAt = value;
      }
    }

    let excerpt = evidenceText.length > 0 ?
      evidenceText.substring(0, Math.min(120, evidenceText.length)) : '家长手工新增';
    return {
      id: `manual-${Date.now()}`,
      studentId: this.drafts.getActiveStudentId(),
      subject: Subject.CHINESE,
      title: '新作业',
      instruction: '新作业',
      textbookRef: '待家长确认',
      dueText: '今天',
      expectedMinutes: 20,
      sourceEvidence: {
        sourceLabel: raw.sourceLabel.length > 0 ? raw.sourceLabel : '家长手工新增',
        excerpt: excerpt,
        batchId: activeBatchId.length > 0 ? activeBatchId : undefined,
        sourceType: activeBatchId.length > 0 ? 'MANUAL_REVIEW' : undefined,
        sourceMessageIds: sourceMessageIds,
        rawText: evidenceText.length > 0 ? evidenceText : '家长手工新增',
        imageRef: '',
        capturedAtEpochMs: capturedAt
      },
      confidence: activeBatchId.length > 0 ? 0.5 : 1.0
    };
  }

  addCandidate(candidate: CandidateAssignment): boolean {
    return this.drafts.addCandidate(candidate);
  }

  publish(): Promise<HomeworkBatchPublishResult> {
    return HomeworkBatchPublishService.instance.publish(this.candidates());
  }
}
