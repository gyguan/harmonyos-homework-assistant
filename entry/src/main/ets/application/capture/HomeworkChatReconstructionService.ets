import { HomeworkImportInboxService } from '../import/HomeworkImportInboxService';
import { HomeworkCaptureSessionStore } from '../../data/local/HomeworkCaptureSessionStore';
import {
  ChatReconstructionOptions,
  ChatReconstructionResult
} from '../../domain/model/ChatReconstructionModels';
import { HomeworkImportPipelineStage, ImportBatch } from '../../domain/model/ImportModels';
import { DeterministicChatReconstructor } from './DeterministicChatReconstructor';

export class HomeworkChatReconstructionService {
  static readonly instance: HomeworkChatReconstructionService = new HomeworkChatReconstructionService();

  private readonly captureStore: HomeworkCaptureSessionStore = HomeworkCaptureSessionStore.instance;
  private readonly reconstructor: DeterministicChatReconstructor = new DeterministicChatReconstructor();

  private constructor() {}

  tryReconstructCaptureSession(sessionId: string, batchId: string,
    targetStartMinuteOfDay: number = -1): ChatReconstructionResult | null {
    try {
      return this.reconstructCaptureSession(sessionId, batchId, targetStartMinuteOfDay);
    } catch {
      let batch = HomeworkImportInboxService.instance.getBatch(batchId);
      if (batch !== null) {
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
          pipelineStage: HomeworkImportPipelineStage.RECONSTRUCTION_FAILED,
          reconstructed: false,
          groupTitle: batch.groupTitle,
          timeBoundaryReached: batch.timeBoundaryReached,
          earliestDetectedTime: batch.earliestDetectedTime,
          reconstructionWarnings: ['CHAT_RECONSTRUCTION_EXCEPTION'],
          understood: batch.understood,
          understandingVersion: batch.understandingVersion,
          pendingReviewMessageIds: batch.pendingReviewMessageIds === undefined ?
            undefined : batch.pendingReviewMessageIds.slice(),
          understandingWarnings: batch.understandingWarnings === undefined ?
            undefined : batch.understandingWarnings.slice(),
          classificationSummary: batch.classificationSummary,
          createdAtEpochMs: batch.createdAtEpochMs,
          status: batch.status,
          messageCount: batch.messageCount,
          candidateCount: 0
        };
        HomeworkImportInboxService.instance.importBatch(
          failed, HomeworkImportInboxService.instance.getMessages(batchId), []);
      }
      return null;
    }
  }

  reconstructCaptureSession(sessionId: string, batchId: string,
    targetStartMinuteOfDay: number = -1): ChatReconstructionResult {
    let session = this.captureStore.getSession(sessionId);
    if (session === null) throw new Error('找不到采集会话，无法重建聊天消息');

    let batch = HomeworkImportInboxService.instance.getBatch(batchId);
    if (batch === null || batch.captureSessionId !== sessionId) {
      throw new Error('采集会话与导入批次不匹配');
    }

    let options: ChatReconstructionOptions = {
      targetStartMinuteOfDay: targetStartMinuteOfDay
    };
    let result = this.reconstructor.reconstruct(
      batchId, this.captureStore.getEvidence(sessionId), options);

    let updated: ImportBatch = {
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
      pipelineStage: HomeworkImportPipelineStage.RECONSTRUCTED,
      reconstructed: true,
      groupTitle: result.groupTitle,
      timeBoundaryReached: targetStartMinuteOfDay >= 0 ? result.timeBoundaryReached : undefined,
      earliestDetectedTime: result.earliestDetectedTime,
      reconstructionWarnings: result.warnings.slice(),
      understood: batch.understood,
      understandingVersion: batch.understandingVersion,
      pendingReviewMessageIds: batch.pendingReviewMessageIds === undefined ?
        undefined : batch.pendingReviewMessageIds.slice(),
      understandingWarnings: batch.understandingWarnings === undefined ?
        undefined : batch.understandingWarnings.slice(),
      classificationSummary: batch.classificationSummary,
      createdAtEpochMs: batch.createdAtEpochMs,
      status: batch.status,
      messageCount: result.messages.length,
      candidateCount: 0
    };
    HomeworkImportInboxService.instance.importBatch(updated, result.messages, []);
    return result;
  }
}
