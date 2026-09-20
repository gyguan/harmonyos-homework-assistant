import { CandidateAssignment, RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../domain/port/HomeworkImportDraftRepository';
import { DefaultHomeworkImportInboxRepository } from './DefaultHomeworkImportInboxRepository';
import { DefaultHomeworkImportLocalDataSource, HomeworkImportLocalDataSource } from '../local/HomeworkImportLocalDataSource';

export class DefaultHomeworkImportDraftRepository implements HomeworkImportDraftRepository {
  static readonly instance: DefaultHomeworkImportDraftRepository = new DefaultHomeworkImportDraftRepository();
  private readonly local: HomeworkImportLocalDataSource = DefaultHomeworkImportLocalDataSource.instance;
  private constructor() {}

  getActiveStudentId(): string { return this.local.getActiveStudentId(); }
  getRawImport(): RawHomeworkImport { return this.local.getRawImport(); }
  getCandidates(): CandidateAssignment[] { return this.local.getCandidates().slice(); }
  replaceRawImport(input: RawHomeworkImport): void { this.local.replaceRawImport(input); }
  replaceCandidates(candidates: CandidateAssignment[]): void {
    this.local.replaceCandidates(candidates);
    this.syncInboxCandidates();
  }

  updateCandidate(candidate: CandidateAssignment): boolean {
    let updated = this.local.updateCandidate(candidate);
    if (updated) this.syncInboxCandidates();
    return updated;
  }

  addCandidate(candidate: CandidateAssignment): boolean {
    let added = this.local.addCandidate(candidate);
    if (added) this.syncInboxCandidates();
    return added;
  }

  removeCandidate(candidateId: string): boolean {
    let removed = this.local.removeCandidate(candidateId);
    if (removed) this.syncInboxCandidates();
    return removed;
  }

  clearCandidates(): void {
    // Publishing/abandoning owns inbox history state. Clearing the legacy active draft must not
    // erase the batch candidate snapshot that provides audit/source traceability.
    this.local.replaceCandidates([]);
  }

  private syncInboxCandidates(): void {
    let inbox = DefaultHomeworkImportInboxRepository.instance;
    let batchId = inbox.getActiveBatchId();
    if (batchId.length === 0) return;
    inbox.syncCandidates(batchId, this.local.getCandidates());
  }
}
