import { HomeworkImportInboxService } from '../../../application/import/HomeworkImportInboxService';
import { DefaultHomeworkImportDraftRepository } from '../../../data/repository/DefaultHomeworkImportDraftRepository';
import {
  HomeworkImportSourceType,
  ImportBatch,
  ImportBatchStatus,
  ImportedMessage
} from '../../../domain/model/ImportModels';
import { CandidateAssignment } from '../../../domain/model/HomeworkModels';
import {
  HomeworkImportInboxSourceFilter,
  HomeworkImportInboxStatusFilter,
  HomeworkImportInboxTimeFilter
} from './HomeworkImportInboxFilters';

export class HomeworkImportInboxViewModel {
  listBatches(): ImportBatch[] {
    return HomeworkImportInboxService.instance.listBatches(
      DefaultHomeworkImportDraftRepository.instance.getActiveStudentId());
  }

  filterBatches(
    batches: ImportBatch[],
    source: HomeworkImportInboxSourceFilter,
    status: HomeworkImportInboxStatusFilter,
    time: HomeworkImportInboxTimeFilter,
    nowEpochMs: number = Date.now()
  ): ImportBatch[] {
    let result: ImportBatch[] = [];
    let earliestEpochMs = this.earliestEpochMs(time, nowEpochMs);
    for (let batch of batches) {
      if (!this.matchesSource(batch.sourceType, source)) continue;
      if (!this.matchesStatus(batch.status, status)) continue;
      if (earliestEpochMs > 0 && batch.createdAtEpochMs < earliestEpochMs) continue;
      result.push(batch);
    }
    return result;
  }

  private matchesSource(
    sourceType: HomeworkImportSourceType,
    filter: HomeworkImportInboxSourceFilter
  ): boolean {
    if (filter === HomeworkImportInboxSourceFilter.ALL) return true;
    if (filter === HomeworkImportInboxSourceFilter.CLIPBOARD) {
      return sourceType === HomeworkImportSourceType.CLIPBOARD;
    }
    if (filter === HomeworkImportInboxSourceFilter.SCREENSHOT) {
      return sourceType === HomeworkImportSourceType.SCREENSHOT;
    }
    if (filter === HomeworkImportInboxSourceFilter.SHARE) {
      return sourceType === HomeworkImportSourceType.SHARE;
    }
    return sourceType === HomeworkImportSourceType.SCREEN_CAPTURE;
  }

  private matchesStatus(status: ImportBatchStatus, filter: HomeworkImportInboxStatusFilter): boolean {
    if (filter === HomeworkImportInboxStatusFilter.ALL) return true;
    if (filter === HomeworkImportInboxStatusFilter.RECEIVED) return status === ImportBatchStatus.RECEIVED;
    if (filter === HomeworkImportInboxStatusFilter.READY) return status === ImportBatchStatus.READY;
    if (filter === HomeworkImportInboxStatusFilter.PUBLISHED) return status === ImportBatchStatus.PUBLISHED;
    if (filter === HomeworkImportInboxStatusFilter.EMPTY) return status === ImportBatchStatus.EMPTY;
    return status === ImportBatchStatus.ABANDONED;
  }

  private earliestEpochMs(filter: HomeworkImportInboxTimeFilter, nowEpochMs: number): number {
    if (filter === HomeworkImportInboxTimeFilter.ALL) return 0;
    let now = new Date(nowEpochMs);
    let daysBack = 0;
    if (filter === HomeworkImportInboxTimeFilter.LAST_7_DAYS) daysBack = 6;
    if (filter === HomeworkImportInboxTimeFilter.LAST_30_DAYS) daysBack = 29;
    return new Date(now.getFullYear(), now.getMonth(), now.getDate() - daysBack).getTime();
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

  activateForManualReview(batchId: string): boolean {
    return HomeworkImportInboxService.instance.activateBatchForManualReview(batchId);
  }

  abandon(batchId: string): boolean {
    return HomeworkImportInboxService.instance.abandonBatch(batchId);
  }
}
