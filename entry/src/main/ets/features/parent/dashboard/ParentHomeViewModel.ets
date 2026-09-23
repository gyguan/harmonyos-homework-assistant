import { Assignment, AssignmentStatus, StudentProfile, TodaySummary } from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';

export class ParentHomeViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository) {
    this.repository = repository;
  }

  student(): StudentProfile {
    return this.repository.getActiveStudent();
  }

  summary(): TodaySummary {
    return this.repository.getCachedSummary();
  }

  assignments(): Assignment[] {
    return this.repository.listCached();
  }

  attentionAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.assignments()) {
      if (item.status === AssignmentStatus.OVERDUE || item.status === AssignmentStatus.NEEDS_REWORK ||
        item.status === AssignmentStatus.SUBMITTED) result.push(item);
    }
    result.sort((left: Assignment, right: Assignment) =>
      this.attentionPriority(left.status) - this.attentionPriority(right.status));
    return result;
  }

  private attentionPriority(status: AssignmentStatus): number {
    if (status === AssignmentStatus.NEEDS_REWORK) return 0;
    if (status === AssignmentStatus.SUBMITTED) return 1;
    if (status === AssignmentStatus.OVERDUE) return 2;
    return 9;
  }

  async refresh(): Promise<boolean> {
    return this.repository.refresh();
  }
}
