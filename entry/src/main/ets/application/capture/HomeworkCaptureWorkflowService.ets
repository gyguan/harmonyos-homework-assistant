import { HomeworkChatReconstructionService } from './HomeworkChatReconstructionService';
import { HomeworkCaptureSessionService } from './HomeworkCaptureSessionService';
import { HomeworkSourceProfileService } from './HomeworkSourceProfileService';
import { DeterministicChatReconstructor } from './DeterministicChatReconstructor';
import { HomeworkImportInboxService } from '../import/HomeworkImportInboxService';
import {
  HomeworkUnderstandingActivationResult,
  HomeworkUnderstandingService
} from '../understanding/HomeworkUnderstandingService';
import { CaptureSession } from '../../domain/model/CaptureModels';
import {
  HomeworkSourceProfile,
  SourceGroupValidationStatus
} from '../../domain/model/HomeworkSourceProfileModels';
import { ImportBatch } from '../../domain/model/ImportModels';

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
      groupValidationStatus: this.validateGroup(profile.groupTitle, result.groupTitle),
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
    let reconstruction = HomeworkChatReconstructionService.instance.reconstructCaptureSession(
      session.id, session.importBatchId, profile.defaultStartMinuteOfDay);
    let validation = this.validateGroup(profile.groupTitle, reconstruction.groupTitle);

    this.writeProfileAudit(
      session.importBatchId,
      profile,
      reconstruction.groupTitle,
      validation,
      allowUnrecognized && validation === SourceGroupValidationStatus.UNRECOGNIZED);

    if (validation === SourceGroupValidationStatus.MISMATCH ||
      (validation === SourceGroupValidationStatus.UNRECOGNIZED && !allowUnrecognized)) {
      return {
        session: session,
        batchId: session.importBatchId,
        detectedGroupTitle: reconstruction.groupTitle,
        groupValidationStatus: validation,
        timeBoundaryReached: reconstruction.timeBoundaryReached,
        earliestDetectedTime: reconstruction.earliestDetectedTime,
        candidateCount: 0,
        pendingReviewCount: 0,
        activated: false,
        needsGroupConfirmation: validation === SourceGroupValidationStatus.UNRECOGNIZED
      };
    }

    let activation: HomeworkUnderstandingActivationResult =
      HomeworkUnderstandingService.instance.understandAndActivate(
        session.importBatchId,
        this.profiles.understandingConfig(profile),
        this.profileStartEpoch(session.startedAtEpochMs, profile.defaultStartMinuteOfDay));

    return {
      session: session,
      batchId: session.importBatchId,
      detectedGroupTitle: reconstruction.groupTitle,
      groupValidationStatus: validation,
      timeBoundaryReached: reconstruction.timeBoundaryReached,
      earliestDetectedTime: reconstruction.earliestDetectedTime,
      candidateCount: activation.result.candidates.length,
      pendingReviewCount: activation.result.pendingReviewMessageIds.length,
      activated: activation.activated,
      needsGroupConfirmation: false
    };
  }

  private writeProfileAudit(batchId: string, profile: HomeworkSourceProfile,
    detectedGroupTitle: string, validation: SourceGroupValidationStatus,
    confirmedByUser: boolean): void {
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

  private profileStartEpoch(anchorEpochMs: number, minuteOfDay: number): number {
    let date = new Date(anchorEpochMs);
    date.setHours(0, 0, 0, 0);
    return date.getTime() + minuteOfDay * 60 * 1000;
  }

  private validateGroup(expected: string, detected: string): SourceGroupValidationStatus {
    let normalizedDetected = this.normalizeTitle(detected);
    if (normalizedDetected.length === 0) return SourceGroupValidationStatus.UNRECOGNIZED;
    return normalizedDetected === this.normalizeTitle(expected) ?
      SourceGroupValidationStatus.MATCHED : SourceGroupValidationStatus.MISMATCH;
  }

  private normalizeTitle(value: string): string {
    return value.trim().replace(/\s+/g, '').toLowerCase();
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
