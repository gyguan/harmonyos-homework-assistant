import {
  ImportBatch,
  ImportedMessage
} from '../model/ImportModels';
import { CandidateAssignment } from '../model/HomeworkModels';

export interface HomeworkImportInboxRepository {
  listBatches(studentId: string): ImportBatch[];
  getBatch(batchId: string): ImportBatch | null;
  getMessages(batchId: string): ImportedMessage[];
  getCandidates(batchId: string): CandidateAssignment[];
  getActiveBatchId(): string;
  saveBatch(batch: ImportBatch, messages: ImportedMessage[], candidates: CandidateAssignment[]): void;
  setActiveBatch(batchId: string): boolean;
  syncCandidates(batchId: string, candidates: CandidateAssignment[]): void;
  markPublished(batchId: string): boolean;
  abandon(batchId: string): boolean;
}
