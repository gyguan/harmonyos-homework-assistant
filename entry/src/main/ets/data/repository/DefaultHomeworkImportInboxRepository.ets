import {
  ImportBatch,
  ImportedMessage
} from '../../domain/model/ImportModels';
import { CandidateAssignment } from '../../domain/model/HomeworkModels';
import { HomeworkImportInboxRepository } from '../../domain/port/HomeworkImportInboxRepository';
import { HomeworkImportInboxStore } from '../local/HomeworkImportInboxStore';

export class DefaultHomeworkImportInboxRepository implements HomeworkImportInboxRepository {
  static readonly instance: DefaultHomeworkImportInboxRepository = new DefaultHomeworkImportInboxRepository();
  private readonly store: HomeworkImportInboxStore = HomeworkImportInboxStore.instance;

  private constructor() {}

  listBatches(studentId: string): ImportBatch[] { return this.store.listBatches(studentId); }
  getBatch(batchId: string): ImportBatch | null { return this.store.getBatch(batchId); }
  getMessages(batchId: string): ImportedMessage[] { return this.store.getMessages(batchId); }
  getCandidates(batchId: string): CandidateAssignment[] { return this.store.getCandidates(batchId); }
  getActiveBatchId(): string { return this.store.getActiveBatchId(); }
  saveBatch(batch: ImportBatch, messages: ImportedMessage[], candidates: CandidateAssignment[]): void {
    this.store.saveBatch(batch, messages, candidates);
  }
  setActiveBatch(batchId: string): boolean { return this.store.setActiveBatch(batchId); }
  syncCandidates(batchId: string, candidates: CandidateAssignment[]): void {
    this.store.syncCandidates(batchId, candidates);
  }
  markPublished(batchId: string): boolean { return this.store.markPublished(batchId); }
  abandon(batchId: string): boolean { return this.store.abandon(batchId); }
}
