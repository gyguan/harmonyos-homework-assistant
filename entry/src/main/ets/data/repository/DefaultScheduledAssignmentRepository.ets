import { ScheduledAssignmentRemoteApi } from '../../application/remote/ScheduledAssignmentRemoteApi';
import {
  ScheduledAssignmentPlan,
  ScheduledAssignmentPlanDraft,
  ScheduledAssignmentRun
} from '../../domain/model/ScheduledAssignmentModels';
import { ScheduledAssignmentRepository } from '../../domain/port/ScheduledAssignmentRepository';

export class DefaultScheduledAssignmentRepository implements ScheduledAssignmentRepository {
  static readonly instance: DefaultScheduledAssignmentRepository =
    new DefaultScheduledAssignmentRepository();

  private readonly remote: ScheduledAssignmentRemoteApi = ScheduledAssignmentRemoteApi.instance;
  private constructor() {}

  async list(studentId: string): Promise<ScheduledAssignmentPlan[]> {
    return this.remote.list(studentId);
  }

  async create(studentId: string, draft: ScheduledAssignmentPlanDraft): Promise<ScheduledAssignmentPlan> {
    return this.remote.create(studentId, draft);
  }

  async update(planId: string, version: number,
    draft: ScheduledAssignmentPlanDraft): Promise<ScheduledAssignmentPlan> {
    return this.remote.update(planId, version, draft);
  }

  async setEnabled(planId: string, version: number, enabled: boolean): Promise<ScheduledAssignmentPlan> {
    return this.remote.setEnabled(planId, version, enabled);
  }

  async delete(planId: string): Promise<void> {
    return this.remote.delete(planId);
  }

  async runs(planId: string): Promise<ScheduledAssignmentRun[]> {
    return this.remote.runs(planId);
  }
}
