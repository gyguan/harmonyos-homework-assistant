import { Assignment, AssignmentStatus, StudentProfile, TodaySummary } from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';

export class StudentHomeViewModel {
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

  nextAssignment(): Assignment | null {
    let summary = this.summary();
    if (summary.nextAssignmentId.length > 0) {
      for (let item of this.assignments()) {
        if (item.id === summary.nextAssignmentId) return item;
      }
    }

    let best: Assignment | null = null;
    for (let item of this.assignments()) {
      if (StudentHomeViewModel.priority(item.status) >= 100) continue;
      if (best === null || StudentHomeViewModel.isBetter(item, best)) best = item;
    }
    return best;
  }

  remainingAssignments(): Assignment[] {
    let next = this.nextAssignment();
    let result: Assignment[] = [];
    for (let item of this.assignments()) {
      if (item.status === AssignmentStatus.COMPLETED || item.status === AssignmentStatus.SUBMITTED) continue;
      if (next !== null && item.id === next.id) continue;
      result.push(item);
    }
    return result;
  }

  attentionCount(): number {
    let count = 0;
    for (let item of this.assignments()) {
      if (item.status === AssignmentStatus.OVERDUE || item.status === AssignmentStatus.NEEDS_REWORK) count++;
    }
    return count;
  }

  actionLabel(assignment: Assignment): string {
    if (assignment.status === AssignmentStatus.IN_PROGRESS || assignment.status === AssignmentStatus.PAUSED) return '继续完成';
    if (assignment.status === AssignmentStatus.READY_TO_SUBMIT) return '去提交';
    if (assignment.status === AssignmentStatus.NEEDS_REWORK) return '继续订正';
    return '开始作业';
  }

  dateLabel(): string {
    let now = new Date();
    return `${now.getMonth() + 1}月${now.getDate()}日`;
  }

  async refresh(): Promise<boolean> {
    return this.repository.refresh();
  }

  private static priority(status: AssignmentStatus): number {
    if (status === AssignmentStatus.IN_PROGRESS) return 0;
    if (status === AssignmentStatus.PAUSED) return 1;
    if (status === AssignmentStatus.NEEDS_REWORK) return 2;
    if (status === AssignmentStatus.OVERDUE) return 3;
    if (status === AssignmentStatus.NOT_STARTED) return 4;
    if (status === AssignmentStatus.READY_TO_SUBMIT) return 5;
    return 100;
  }

  private static isBetter(candidate: Assignment, current: Assignment): boolean {
    let candidatePriority = StudentHomeViewModel.priority(candidate.status);
    let currentPriority = StudentHomeViewModel.priority(current.status);
    if (candidatePriority !== currentPriority) return candidatePriority < currentPriority;
    if (candidate.dueAtEpochMs > 0 && current.dueAtEpochMs <= 0) return true;
    if (candidate.dueAtEpochMs <= 0 && current.dueAtEpochMs > 0) return false;
    if (candidate.dueAtEpochMs > 0 && current.dueAtEpochMs > 0) {
      return candidate.dueAtEpochMs < current.dueAtEpochMs;
    }
    return false;
  }
}
