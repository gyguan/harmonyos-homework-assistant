import {
  ScheduledAssignmentPlan,
  ScheduledAssignmentPlanDraft,
  ScheduledAssignmentRun
} from '../model/ScheduledAssignmentModels';

export interface ScheduledAssignmentRepository {
  list(studentId: string): Promise<ScheduledAssignmentPlan[]>;
  create(studentId: string, draft: ScheduledAssignmentPlanDraft): Promise<ScheduledAssignmentPlan>;
  update(planId: string, version: number, draft: ScheduledAssignmentPlanDraft): Promise<ScheduledAssignmentPlan>;
  setEnabled(planId: string, version: number, enabled: boolean): Promise<ScheduledAssignmentPlan>;
  delete(planId: string): Promise<void>;
  runs(planId: string): Promise<ScheduledAssignmentRun[]>;
}
