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
    return result;
  }

  recentSubmitted(): Assignment | null {
    for (let item of this.assignments()) {
      if (item.status === AssignmentStatus.SUBMITTED || item.status === AssignmentStatus.COMPLETED ||
        item.status === AssignmentStatus.NEEDS_REWORK) return item;
    }
    return null;
  }

  async refresh(): Promise<boolean> {
    return this.repository.refresh();
  }
}
