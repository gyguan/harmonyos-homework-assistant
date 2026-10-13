import { Assignment, AssignmentStatus, AssignmentType } from '../model/HomeworkModels';
import { AssignmentFilter, AssignmentTypeFilter } from '../model/AssignmentFilter';
import { AssignmentTaskDate } from './AssignmentTaskDate';

export class AssignmentQuery {
  static filter(items: Assignment[], filter: AssignmentFilter): Assignment[] {
    let result: Assignment[] = [];
    for (let item of items) {
      if (!AssignmentQuery.matchesType(item, filter.assignmentType)) continue;
      if (filter.subjectCode !== 'ALL' && item.subjectCode !== filter.subjectCode) continue;
      if (!AssignmentQuery.matchesDate(item, filter.fromEpochMs, filter.toEpochMs)) continue;
      if (!AssignmentQuery.matchesStatus(item, filter.statuses)) continue;
      AssignmentQuery.insertSorted(result, item);
    }
    return result;
  }

  static sort(items: Assignment[]): Assignment[] {
    let result: Assignment[] = [];
    for (let item of items) AssignmentQuery.insertSorted(result, item);
    return result;
  }

  private static matchesType(item: Assignment, filter: AssignmentTypeFilter): boolean {
    if (filter === AssignmentTypeFilter.ALL) return true;
    if (filter === AssignmentTypeFilter.SCHOOL) return item.assignmentType === AssignmentType.SCHOOL;
    return item.assignmentType === AssignmentType.EXTRA;
  }

  private static matchesDate(item: Assignment, fromEpochMs: number, toEpochMs: number): boolean {
    if (fromEpochMs <= 0 && toEpochMs <= 0) return true;
    let fromDate = fromEpochMs > 0 ? AssignmentTaskDate.fromEpochMs(fromEpochMs) : '';
    let toDate = toEpochMs > 0 ? AssignmentTaskDate.fromEpochMs(toEpochMs) : '';
    if (fromDate.length > 0 && item.taskDate < fromDate) return false;
    if (toDate.length > 0 && item.taskDate > toDate) return false;
    return true;
  }

  private static matchesStatus(item: Assignment, statuses: AssignmentStatus[]): boolean {
    if (statuses.length === 0) return true;
    for (let status of statuses) if (item.status === status) return true;
    return false;
  }

  private static insertSorted(result: Assignment[], item: Assignment): void {
    let index = result.length;
    for (let i = 0; i < result.length; i++) {
      if (AssignmentQuery.compare(item, result[i]) < 0) {
        index = i;
        break;
      }
    }
    result.splice(index, 0, item);
  }

  private static compare(left: Assignment, right: Assignment): number {
    let leftPriority = AssignmentQuery.statusPriority(left.status);
    let rightPriority = AssignmentQuery.statusPriority(right.status);
    if (leftPriority !== rightPriority) return leftPriority - rightPriority;
    if (left.taskDate !== right.taskDate) return left.taskDate < right.taskDate ? -1 : 1;
    if (left.title !== right.title) return left.title < right.title ? -1 : 1;
    if (left.id === right.id) return 0;
    return left.id < right.id ? -1 : 1;
  }

  private static statusPriority(status: AssignmentStatus): number {
    if (status === AssignmentStatus.IN_PROGRESS) return 0;
    if (status === AssignmentStatus.PAUSED) return 1;
    if (status === AssignmentStatus.NEEDS_REWORK) return 2;
    if (status === AssignmentStatus.OVERDUE) return 3;
    if (status === AssignmentStatus.READY_TO_SUBMIT) return 4;
    if (status === AssignmentStatus.NOT_STARTED) return 5;
    if (status === AssignmentStatus.SUBMITTED) return 6;
    if (status === AssignmentStatus.COMPLETED) return 7;
    return 100;
  }
}
