import { HomeworkImportInboxService } from '../../../application/import/HomeworkImportInboxService';
import { DefaultHomeworkImportDraftRepository } from '../../../data/repository/DefaultHomeworkImportDraftRepository';
import {
  ImportBatch,
  ImportedMessage
} from '../../../domain/model/ImportModels';
import { CandidateAssignment } from '../../../domain/model/HomeworkModels';

export class HomeworkImportInboxViewModel {
  listBatches(): ImportBatch[] {
    return HomeworkImportInboxService.instance.listBatches(
      DefaultHomeworkImportDraftRepository.instance.getActiveStudentId());
  }

  batch(batchId: string): ImportBatch | null {
    return HomeworkImportInboxService.instance.getBatch(batchId);
  }

  messages(batchId: string): ImportedMessage[] {
    return HomeworkImportInboxService.instance.getMessages(batchId);
  }

  candidates(batchId: string): CandidateAssignment[] {
    return HomeworkImportInboxService.instance.getCandidates(batchId);
  }

  activate(batchId: string): boolean {
    return HomeworkImportInboxService.instance.activateBatch(batchId);
  }

  abandon(batchId: string): boolean {
    return HomeworkImportInboxService.instance.abandonBatch(batchId);
  }
}
