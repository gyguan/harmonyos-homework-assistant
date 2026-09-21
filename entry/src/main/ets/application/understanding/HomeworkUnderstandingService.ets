import { HomeworkImportInboxService } from '../import/HomeworkImportInboxService';
import {
  HOMEWORK_UNDERSTANDING_RULESET_VERSION,
  HomeworkMessageClassification,
  HomeworkUnderstandingConfig,
  HomeworkUnderstandingResult
} from '../../domain/model/HomeworkUnderstandingModels';
import { ImportBatch, ImportBatchStatus, ImportedMessage } from '../../domain/model/ImportModels';
import { HomeworkUnderstandingPipeline } from './HomeworkUnderstandingPipeline';

export interface HomeworkUnderstandingActivationResult {
  result: HomeworkUnderstandingResult;
  activated: boolean;
}

export class HomeworkUnderstandingService {
  static readonly instance: HomeworkUnderstandingService = new HomeworkUnderstandingService();

  private readonly inbox: HomeworkImportInboxService = HomeworkImportInboxService.instance;
  private readonly pipeline: HomeworkUnderstandingPipeline = new HomeworkUnderstandingPipeline();

  private constructor() {}

  understandBatch(batchId: string, config: HomeworkUnderstandingConfig,
    minTimestampEpochMs: number = 0): HomeworkUnderstandingResult {
    let batch = this.inbox.getBatch(batchId);
    if (batch === null) throw new Error('找不到待理解的导入批次');

    let allMessages = this.inbox.getMessages(batchId);
    let messages = this.messagesWithinRange(allMessages, minTimestampEpochMs);
    let filteredCount = allMessages.length - messages.length;
    let result = this.pipeline.understand(
      batch.id,
      batch.studentId,
      batch.sourceLabel,
      `${batch.sourceType}`,
      messages,
      config);
    if (filteredCount > 0) result.warnings.push(`TIME_RANGE_FILTERED:${filteredCount}`);

    let updated = this.withUnderstandingResult(batch, result);
    this.inbox.importBatch(updated, messages, result.candidates);
    return result;
  }

  tryUnderstandBatch(batchId: string,
    config: HomeworkUnderstandingConfig, minTimestampEpochMs: number = 0): HomeworkUnderstandingResult | null {
    try {
      return this.understandBatch(batchId, config, minTimestampEpochMs);
    } catch {
      this.recordFailure(batchId);
      return null;
    }
  }

  understandAndActivate(batchId: string,
    config: HomeworkUnderstandingConfig,
    minTimestampEpochMs: number = 0): HomeworkUnderstandingActivationResult {
    let result = this.understandBatch(batchId, config, minTimestampEpochMs);
    let activated = result.candidates.length > 0 && this.inbox.activateBatch(batchId);
    return {
      result: result,
      activated: activated
    };
  }

  private withUnderstandingResult(batch: ImportBatch,
    result: HomeworkUnderstandingResult): ImportBatch {
    return {
      id: batch.id,
      studentId: batch.studentId,
      sourceType: batch.sourceType,
      sourceLabel: batch.sourceLabel,
      sourceProfileId: batch.sourceProfileId,
      sourceProfileName: batch.sourceProfileName,
      expectedGroupTitle: batch.expectedGroupTitle,
      profileStartTime: batch.profileStartTime,
      groupValidationStatus: batch.groupValidationStatus,
      groupConfirmedByUser: batch.groupConfirmedByUser,
      captureSessionId: batch.captureSessionId,
      reconstructed: batch.reconstructed,
      groupTitle: batch.groupTitle,
      timeBoundaryReached: batch.timeBoundaryReached,
      earliestDetectedTime: batch.earliestDetectedTime,
      reconstructionWarnings: batch.reconstructionWarnings === undefined ?
        undefined : batch.reconstructionWarnings.slice(),
      understood: true,
      understandingVersion: HOMEWORK_UNDERSTANDING_RULESET_VERSION,
      pendingReviewMessageIds: result.pendingReviewMessageIds.slice(),
      understandingWarnings: result.warnings.slice(),
      classificationSummary: this.classificationSummary(result),
      createdAtEpochMs: batch.createdAtEpochMs,
      status: result.candidates.length > 0 ? ImportBatchStatus.READY :
        (result.pendingReviewMessageIds.length > 0 ? ImportBatchStatus.RECEIVED : ImportBatchStatus.EMPTY),
      messageCount: batch.messageCount,
      candidateCount: result.candidates.length
    };
  }

  private recordFailure(batchId: string): void {
    let batch = this.inbox.getBatch(batchId);
    if (batch === null) return;
    let messages = this.inbox.getMessages(batchId);
    let candidates = this.inbox.getCandidates(batchId);
    let warnings: string[] = batch.understandingWarnings === undefined ?
      [] : batch.understandingWarnings.slice();
    if (warnings.indexOf('HOMEWORK_UNDERSTANDING_EXCEPTION') < 0) {
      warnings.push('HOMEWORK_UNDERSTANDING_EXCEPTION');
    }
    let failed: ImportBatch = {
      id: batch.id,
      studentId: batch.studentId,
      sourceType: batch.sourceType,
      sourceLabel: batch.sourceLabel,
      sourceProfileId: batch.sourceProfileId,
      sourceProfileName: batch.sourceProfileName,
      expectedGroupTitle: batch.expectedGroupTitle,
      profileStartTime: batch.profileStartTime,
      groupValidationStatus: batch.groupValidationStatus,
      groupConfirmedByUser: batch.groupConfirmedByUser,
      captureSessionId: batch.captureSessionId,
      reconstructed: batch.reconstructed,
      groupTitle: batch.groupTitle,
      timeBoundaryReached: batch.timeBoundaryReached,
      earliestDetectedTime: batch.earliestDetectedTime,
      reconstructionWarnings: batch.reconstructionWarnings === undefined ?
        undefined : batch.reconstructionWarnings.slice(),
      understood: false,
      understandingVersion: batch.understandingVersion,
      pendingReviewMessageIds: batch.pendingReviewMessageIds === undefined ?
        undefined : batch.pendingReviewMessageIds.slice(),
      understandingWarnings: warnings,
      classificationSummary: batch.classificationSummary,
      createdAtEpochMs: batch.createdAtEpochMs,
      status: batch.status,
      messageCount: messages.length,
      candidateCount: candidates.length
    };
    this.inbox.importBatch(failed, messages, candidates);
  }

  private messagesWithinRange(messages: ImportedMessage[], minTimestampEpochMs: number): ImportedMessage[] {
    if (minTimestampEpochMs <= 0) return messages;
    let result: ImportedMessage[] = [];
    for (let message of messages) {
      if (message.timestampEpochMs > 0 && message.timestampEpochMs < minTimestampEpochMs) continue;
      result.push(message);
    }
    return result;
  }

  private classificationSummary(result: HomeworkUnderstandingResult): string {
    let homework = 0;
    let revision = 0;
    let preparation = 0;
    let notice = 0;
    let chat = 0;
    let unknown = 0;

    for (let item of result.classifiedMessages) {
      if (item.classification === HomeworkMessageClassification.HOMEWORK) homework++;
      else if (item.classification === HomeworkMessageClassification.HOMEWORK_REVISION) revision++;
      else if (item.classification === HomeworkMessageClassification.PREPARATION) preparation++;
      else if (item.classification === HomeworkMessageClassification.NOTICE) notice++;
      else if (item.classification === HomeworkMessageClassification.CHAT) chat++;
      else unknown++;
    }

    return `HOMEWORK=${homework};REVISION=${revision};PREPARATION=${preparation};` +
      `NOTICE=${notice};CHAT=${chat};UNKNOWN=${unknown}`;
  }
}
