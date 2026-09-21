import { HomeworkChatReconstructionService } from './HomeworkChatReconstructionService';
import { HomeworkCaptureSessionService } from './HomeworkCaptureSessionService';
import { HomeworkSourceProfileService } from './HomeworkSourceProfileService';
import { DeterministicChatReconstructor } from './DeterministicChatReconstructor';
import { HomeworkImportInboxService } from '../import/HomeworkImportInboxService';
import { HomeworkUnderstandingService } from '../understanding/HomeworkUnderstandingService';
import { CaptureSession } from '../../domain/model/CaptureModels';
import {
  HomeworkSourceProfile,
  SourceGroupValidationStatus
} from '../../domain/model/HomeworkSourceProfileModels';
import {
  HomeworkImportPipelineStage,
  ImportBatch
} from '../../domain/model/ImportModels';

export interface HomeworkCaptureWorkflowProgress {
  session: CaptureSession;
  profile: HomeworkSourceProfile;
  detectedGroupTitle: string;
  groupValidationStatus: SourceGroupValidationStatus;
  timeBoundaryReached: boolean;
  earliestDetectedTime: string;
}

export interface HomeworkCaptureWorkflowResult {
  session: CaptureSession;
  batchId: string;
  detectedGroupTitle: string;
  groupValidationStatus: SourceGroupValidationStatus;
  timeBoundaryReached: boolean;
  earliestDetectedTime: string;
  candidateCount: number;
  pendingReviewCount: number;
  activated: boolean;
  needsGroupConfirmation: boolean;
  reconstructionSucceeded: boolean;
  understandingSucceeded: boolean;
}

export class HomeworkCaptureWorkflowService {
  static readonly instance: HomeworkCaptureWorkflowService = new HomeworkCaptureWorkflowService();

  private readonly capture: HomeworkCaptureSessionService = HomeworkCaptureSessionService.instance;
  private readonly profiles: HomeworkSourceProfileService = HomeworkSourceProfileService.instance;
  private readonly inbox: HomeworkImportInboxService = HomeworkImportInboxService.instance;
  private readonly previewReconstructor: DeterministicChatReconstructor = new DeterministicChatReconstructor();

  private constructor() {}

  start(studentId: string): CaptureSession {
    let profile = this.requireActiveProfile(studentId);
    this.profiles.markUsed(profile.id);
    return this.capture.start(studentId, profile.id);
  }

  async progress(): Promise<HomeworkCaptureWorkflowProgress | null> {
    let session = await this.capture.sampleLatestFrame();
    if (session === null) return null;
    let profile = this.requireProfile(session.sourceProfileId, session.studentId);
    let evidence = this.capture.getEvidence(session.id);
    let result = this.previewReconstructor.reconstruct(
      `preview-${session.id}`,
      evidence,
      { targetStartMinuteOfDay: profile.defaultStartMinuteOfDay });
    return {
      session: session,
      profile: profile,
      detectedGroupTitle: result.groupTitle,
      groupValidationStatus: this.validationForReconstruction(
        profile.groupTitle, result.groupTitle, result.warnings),
      timeBoundaryReached: result.timeBoundaryReached,
      earliestDetectedTime: result.earliestDetectedTime
    };
  }

  async finishByUser(): Promise<HomeworkCaptureWorkflowResult | null> {
    let session = await this.capture.stopByUser();
    if (session === null || session.importBatchId.length === 0) return null;
    return this.finalize(session, false);
  }

  finalizeCompletedSession(sessionId: string): HomeworkCaptureWorkflowResult | null {
    let session = this.capture.getSession(sessionId);
    if (session === null || session.importBatchId.length === 0) return null;
    return this.finalize(session, false);
  }

  confirmUnrecognizedAndContinue(batchId: string): HomeworkCaptureWorkflowResult | null {
    let batch = this.inbox.getBatch(batchId);
    if (batch === null || batch.captureSessionId === undefined) return null;
    let session = this.capture.getSession(batch.captureSessionId);
    if (session === null) return null;
    return this.finalize(session, true);
  }

  private finalize(session: CaptureSession, allowUnrecognized: boolean): HomeworkCaptureWorkflowResult {
    let profile = this.requireProfile(session.sourceProfileId, session.studentId);
    let batch = this.requireBatch(session.importBatchId);

    if (batch.pipelineStage === HomeworkImportPipelineStage.ACTIVATED) {
      return this.resultFromStored(session, batch, true);
    }

    if (batch.reconstructed !== true) {
      let reconstruction = HomeworkChatReconstructionService.instance.tryReconstructCaptureSession(
        session.id, session.importBatchId, profile.defaultStartMinuteOfDay);
      if (reconstruction === null) {
        this.writeProfileAudit(
          session.importBatchId,
          profile,
          '',
          SourceGroupValidationStatus.UNRECOGNIZED,
          false,
          HomeworkImportPipelineStage.RECONSTRUCTION_FAILED);
        return this.resultFromStored(
          session, this.requireBatch(session.importBatchId), false);
      }
      batch = this.requireBatch(session.importBatchId);
    }

    let validation = this.validationForReconstruction(
      profile.groupTitle,
      batch.groupTitle === undefined ? '' : batch.groupTitle,
      batch.reconstructionWarnings === undefined ? [] : batch.reconstructionWarnings);

    let confirmedByUser = allowUnrecognized &&
      validation === SourceGroupValidationStatus.UNRECOGNIZED;
    let validationStage = this.validationStage(validation, allowUnrecognized);

    this.writeProfileAudit(
      session.importBatchId,
      profile,
      batch.groupTitle === undefined ? '' : batch.groupTitle,
      validation,
      confirmedByUser,
      validationStage);
    batch = this.requireBatch(session.importBatchId);

    if (validation === SourceGroupValidationStatus.MISMATCH ||
      validation === SourceGroupValidationStatus.CONFLICT ||
      (validation === SourceGroupValidationStatus.UNRECOGNIZED && !allowUnrecognized)) {
      return this.resultFromStored(session, batch, false);
    }

    if (batch.understood !== true) {
      let understanding = HomeworkUnderstandingService.instance.tryUnderstandBatch(
        session.importBatchId,
        this.profiles.understandingConfig(profile),
        this.profileStartEpoch(session.startedAtEpochMs, profile.defaultStartMinuteOfDay));
      if (understanding === null) {
        return this.resultFromStored(
          session, this.requireBatch(session.importBatchId), false);
      }
      batch = this.requireBatch(session.importBatchId);
    }

    let candidates = this.inbox.getCandidates(session.importBatchId);
    let activated = batch.pipelineStage === HomeworkImportPipelineStage.ACTIVATED;
    if (!activated && candidates.length > 0) {
      activated = this.inbox.activateBatch(session.importBatchId);
      if (activated) {
        this.updatePipelineStage(
          session.importBatchId, HomeworkImportPipelineStage.ACTIVATED);
        batch = this.requireBatch(session.importBatchId);
      }
    }

    return this.resultFromStored(session, batch, activated);
  }

  private validationStage(validation: SourceGroupValidationStatus,
    allowUnrecognized: boolean): HomeworkImportPipelineStage {
    if (validation === SourceGroupValidationStatus.MISMATCH ||
      validation === SourceGroupValidationStatus.CONFLICT) {
      return HomeworkImportPipelineStage.BLOCKED_SOURCE;
    }
    if (validation === SourceGroupValidationStatus.UNRECOGNIZED && !allowUnrecognized) {
      return HomeworkImportPipelineStage.RECONSTRUCTED;
    }
    return HomeworkImportPipelineStage.SOURCE_VALIDATED;
  }

  private resultFromStored(session: CaptureSession, batch: ImportBatch,
    activated: boolean): HomeworkCaptureWorkflowResult {
    let validation = this.storedValidation(batch);
    let candidates = this.inbox.getCandidates(batch.id);
    let pendingReviewCount = batch.pendingReviewMessageIds === undefined ?
      0 : batch.pendingReviewMessageIds.length;
    return {
      session: session,
      batchId: batch.id,
      detectedGroupTitle: batch.groupTitle === undefined ? '' : batch.groupTitle,
      groupValidationStatus: validation,
      timeBoundaryReached: batch.timeBoundaryReached === true,
      earliestDetectedTime: batch.earliestDetectedTime === undefined ? '' : batch.earliestDetectedTime,
      candidateCount: candidates.length,
      pendingReviewCount: pendingReviewCount,
      activated: activated || batch.pipelineStage === HomeworkImportPipelineStage.ACTIVATED,
      needsGroupConfirmation: validation === SourceGroupValidationStatus.UNRECOGNIZED &&
        batch.groupConfirmedByUser !== true &&
        batch.pipelineStage !== HomeworkImportPipelineStage.RECONSTRUCTION_FAILED,
      reconstructionSucceeded: batch.reconstructed === true,
      understandingSucceeded: batch.understood === true
    };
  }

  private storedValidation(batch: ImportBatch): SourceGroupValidationStatus {
    if (batch.groupValidationStatus === SourceGroupValidationStatus.MATCHED) {
      return SourceGroupValidationStatus.MATCHED;
    }
    if (batch.groupValidationStatus === SourceGroupValidationStatus.MISMATCH) {
      return SourceGroupValidationStatus.MISMATCH;
    }
    if (batch.groupValidationStatus === SourceGroupValidationStatus.CONFLICT) {
      return SourceGroupValidationStatus.CONFLICT;
    }
    return SourceGroupValidationStatus.UNRECOGNIZED;
  }

  private writeProfileAudit(batchId: string, profile: HomeworkSourceProfile,
    detectedGroupTitle: string, validation: SourceGroupValidationStatus,
    confirmedByUser: boolean, pipelineStage: HomeworkImportPipelineStage): void {
    let batch = this.inbox.getBatch(batchId);
    if (batch === null) return;
    let updated: ImportBatch = {
      id: batch.id,
      studentId: batch.studentId,
      sourceType: batch.sourceType,
      sourceLabel: batch.sourceLabel,
      sourceProfileId: profile.id,
      sourceProfileName: profile.name,
      expectedGroupTitle: profile.groupTitle,
      profileStartTime: this.profiles.formatStartTime(profile),
      groupValidationStatus: validation,
      groupConfirmedByUser: confirmedByUser,
      captureSessionId: batch.captureSessionId,
      pipelineStage: pipelineStage,
      reconstructed: batch.reconstructed,
      groupTitle: detectedGroupTitle,
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
      status: batch.status,
      messageCount: batch.messageCount,
      candidateCount: batch.candidateCount
    };
    this.inbox.importBatch(
      updated,
      this.inbox.getMessages(batchId),
      this.inbox.getCandidates(batchId));
  }

  private updatePipelineStage(batchId: string, pipelineStage: HomeworkImportPipelineStage): void {
    let batch = this.requireBatch(batchId);
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
      pipelineStage: pipelineStage,
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
      status: batch.status,
      messageCount: batch.messageCount,
      candidateCount: batch.candidateCount
    };
    this.inbox.importBatch(
      updated,
      this.inbox.getMessages(batchId),
      this.inbox.getCandidates(batchId));
  }

  private profileStartEpoch(anchorEpochMs: number, minuteOfDay: number): number {
    let date = new Date(anchorEpochMs);
    date.setHours(0, 0, 0, 0);
    return date.getTime() + minuteOfDay * 60 * 1000;
  }

  validationForReconstruction(expected: string, detected: string,
    warnings: string[]): SourceGroupValidationStatus {
    if (warnings.indexOf('GROUP_TITLE_CONFLICT') >= 0) {
      return SourceGroupValidationStatus.CONFLICT;
    }
    return this.validateGroupTitle(expected, detected);
  }

  validateGroupTitle(expected: string, detected: string): SourceGroupValidationStatus {
    let normalizedDetected = this.normalizeTitle(detected);
    if (normalizedDetected.length === 0) return SourceGroupValidationStatus.UNRECOGNIZED;
    return normalizedDetected === this.normalizeTitle(expected) ?
      SourceGroupValidationStatus.MATCHED : SourceGroupValidationStatus.MISMATCH;
  }

  private normalizeTitle(value: string): string {
    let normalized = value.trim()
      .replace(/\s+/g, '')
      .replace(/（/g, '(')
      .replace(/）/g, ')')
      .toLowerCase();
    let memberCount = normalized.match(/\(\d{1,4}\)$/);
    if (memberCount !== null) {
      normalized = normalized.substring(0, normalized.length - memberCount[0].length);
    }
    return normalized;
  }

  private requireBatch(batchId: string): ImportBatch {
    let batch = this.inbox.getBatch(batchId);
    if (batch === null) throw new Error('找不到采集导入批次');
    return batch;
  }

  private requireActiveProfile(studentId: string): HomeworkSourceProfile {
    let profile = this.profiles.getActiveProfile(studentId);
    if (profile === null) throw new Error('请先配置班级采集设置');
    return profile;
  }

  private requireProfile(profileId: string, studentId: string): HomeworkSourceProfile {
    let profile = profileId.length > 0 ? this.profiles.getProfile(profileId) : null;
    if (profile === null) profile = this.profiles.getActiveProfile(studentId);
    if (profile === null) throw new Error('找不到本次采集使用的班级配置');
    return profile;
  }
}
