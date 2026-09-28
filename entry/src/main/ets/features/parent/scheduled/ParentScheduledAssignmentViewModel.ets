import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultScheduledAssignmentRepository } from '../../../data/repository/DefaultScheduledAssignmentRepository';
import {
  ScheduledAssignmentPlan,
  ScheduledAssignmentPlanDraft,
  ScheduledAssignmentRun
} from '../../../domain/model/ScheduledAssignmentModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { ScheduledAssignmentRepository } from '../../../domain/port/ScheduledAssignmentRepository';

export class ParentScheduledAssignmentViewModel {
  private readonly family: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  private readonly repository: ScheduledAssignmentRepository =
    DefaultScheduledAssignmentRepository.instance;

  studentName(): string {
    return this.family.getStudent().name;
  }

  studentId(): string {
    return this.family.getActiveStudentId();
  }

  async list(): Promise<ScheduledAssignmentPlan[]> {
    return this.repository.list(this.studentId());
  }

  async create(draft: ScheduledAssignmentPlanDraft): Promise<ScheduledAssignmentPlan> {
    return this.repository.create(this.studentId(), draft);
  }

  async update(plan: ScheduledAssignmentPlan,
    draft: ScheduledAssignmentPlanDraft): Promise<ScheduledAssignmentPlan> {
    return this.repository.update(plan.id, plan.version, draft);
  }

  async toggle(plan: ScheduledAssignmentPlan): Promise<ScheduledAssignmentPlan> {
    return this.repository.setEnabled(plan.id, plan.version, plan.status !== 'ENABLED');
  }

  async delete(plan: ScheduledAssignmentPlan): Promise<void> {
    return this.repository.delete(plan.id);
  }

  async runs(plan: ScheduledAssignmentPlan): Promise<ScheduledAssignmentRun[]> {
    return this.repository.runs(plan.id);
  }
}
