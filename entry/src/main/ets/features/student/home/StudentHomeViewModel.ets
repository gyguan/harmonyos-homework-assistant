import {
  Assignment,
  AssignmentStatus,
  StudentProfile,
  TodaySummary
} from '../../../domain/model/HomeworkModels';
import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';
import { AssignmentAttentionKind, AssignmentAttentionPolicy, AssignmentAttentionResult } from '../../../domain/service/AssignmentAttentionPolicy';

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

  assignments(studentId: string = ''): Assignment[] {
    let source = this.repository.listCached();
    if (studentId.length === 0) return source;
    let owned: Assignment[] = [];
    for (let item of source) {
      if (item.studentId === studentId) owned.push(item);
    }
    return owned;
  }

  assignment(assignmentId: string): Assignment | null {
    return this.repository.getCached(assignmentId);
  }

  async performAction(assignmentId: string, action: AssignmentAction): Promise<Assignment> {
    return this.repository.performAction(assignmentId, action);
  }

  attention(studentId: string = ''): AssignmentAttentionResult {
    return AssignmentAttentionPolicy.studentResult(this.assignments(studentId));
  }

  attentionText(): string {
    return this.attention().text;
  }

  attentionKind(): AssignmentAttentionKind {
    return this.attention().kind;
  }

  pendingAssignments(studentId: string = ''): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.assignments(studentId)) {
      if (!StudentHomeViewModel.isUnfinished(item.status)) continue;
      StudentHomeViewModel.insertByPriority(result, item);
    }
    return result;
  }

  async refresh(): Promise<boolean> {
    return this.repository.refresh();
  }

  private static isUnfinished(status: AssignmentStatus): boolean {
    return status !== AssignmentStatus.SUBMITTED && status !== AssignmentStatus.COMPLETED;
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

  private static insertByPriority(result: Assignment[], item: Assignment): void {
    for (let index = 0; index < result.length; index++) {
      if (StudentHomeViewModel.isBetter(item, result[index])) {
        result.splice(index, 0, item);
        return;
      }
    }
    result.push(item);
  }

  private static isBetter(candidate: Assignment, current: Assignment): boolean {
    let candidatePriority = StudentHomeViewModel.priority(candidate.status);
    let currentPriority = StudentHomeViewModel.priority(current.status);
    if (candidatePriority !== currentPriority) return candidatePriority < currentPriority;

    let candidateDue = candidate.dueAtEpochMs > 0 ? candidate.dueAtEpochMs : Number.MAX_SAFE_INTEGER;
    let currentDue = current.dueAtEpochMs > 0 ? current.dueAtEpochMs : Number.MAX_SAFE_INTEGER;
    if (candidateDue !== currentDue) return candidateDue < currentDue;
    return candidate.id < current.id;
  }
}
