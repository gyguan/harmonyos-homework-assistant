import { HomeworkCaptureSessionService } from '../../../application/capture/HomeworkCaptureSessionService';
import {
  HomeworkCaptureWorkflowProgress,
  HomeworkCaptureWorkflowResult,
  HomeworkCaptureWorkflowService
} from '../../../application/capture/HomeworkCaptureWorkflowService';
import { HomeworkSourceProfileService } from '../../../application/capture/HomeworkSourceProfileService';
import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { CaptureSession } from '../../../domain/model/CaptureModels';
import { HomeworkSourceProfile } from '../../../domain/model/HomeworkSourceProfileModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';

export class HomeworkCaptureViewModel {
  private readonly family: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  private readonly sessions: HomeworkCaptureSessionService = HomeworkCaptureSessionService.instance;
  private readonly workflow: HomeworkCaptureWorkflowService = HomeworkCaptureWorkflowService.instance;
  private readonly profiles: HomeworkSourceProfileService = HomeworkSourceProfileService.instance;

  hasActiveProfile(): boolean {
    return this.profiles.getActiveProfile(this.family.getActiveStudentId()) !== null;
  }

  activeOrSession(sessionId: string): CaptureSession | null {
    let active = this.sessions.getActiveSession();
    if (active !== null) return active;
    if (sessionId.length === 0) return null;
    return this.sessions.getSession(sessionId);
  }

  progress(): Promise<HomeworkCaptureWorkflowProgress | null> {
    return this.workflow.progress();
  }

  start(): CaptureSession {
    return this.workflow.start(this.family.getActiveStudentId());
  }

  finishByUser(): Promise<HomeworkCaptureWorkflowResult | null> {
    return this.workflow.finishByUser();
  }

  finalizeCompletedSession(sessionId: string): HomeworkCaptureWorkflowResult | null {
    return this.workflow.finalizeCompletedSession(sessionId);
  }

  confirmUnrecognizedAndContinue(batchId: string): HomeworkCaptureWorkflowResult | null {
    return this.workflow.confirmUnrecognizedAndContinue(batchId);
  }

  cancel(): Promise<CaptureSession | null> {
    return this.sessions.cancel();
  }

  formatStartTime(profile: HomeworkSourceProfile): string {
    return this.profiles.formatStartTime(profile);
  }
}
