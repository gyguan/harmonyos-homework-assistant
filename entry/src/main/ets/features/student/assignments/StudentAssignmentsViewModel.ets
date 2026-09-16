import {
  AssignmentDateFilter,
  AssignmentFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';

export class StudentAssignmentsViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository) {
    this.repository = repository;
  }

  assignments(typeFilter: AssignmentTypeFilter, subjectCode: string,
    dateFilter: AssignmentDateFilter, statuses: AssignmentStatus[] = []): Assignment[] {
    return this.repository.listCached(this.buildFilter(typeFilter, subjectCode, dateFilter, statuses));
  }

  allCount(): number {
    return this.assignments(AssignmentTypeFilter.ALL, 'ALL', AssignmentDateFilter.ALL).length;
  }

  typeCount(typeFilter: AssignmentTypeFilter): number {
    return this.assignments(typeFilter, 'ALL', AssignmentDateFilter.ALL).length;
  }

  subjectCount(subjectCode: string): number {
    return this.assignments(AssignmentTypeFilter.ALL, subjectCode, AssignmentDateFilter.ALL).length;
  }

  dateCount(dateFilter: AssignmentDateFilter): number {
    return this.assignments(AssignmentTypeFilter.ALL, 'ALL', dateFilter).length;
  }

  assignment(assignmentId: string): Assignment | null {
    return this.repository.getCached(assignmentId);
  }

  async refresh(): Promise<boolean> {
    return this.repository.refresh();
  }

  private buildFilter(typeFilter: AssignmentTypeFilter, subjectCode: string,
    dateFilter: AssignmentDateFilter, statuses: AssignmentStatus[]): AssignmentFilter {
    let fromEpochMs = 0;
    let toEpochMs = 0;
    let undatedOnly = dateFilter === AssignmentDateFilter.UNDATED;
    let today = StudentAssignmentsViewModel.startOfDay(Date.now());
    if (dateFilter === AssignmentDateFilter.TODAY) {
      fromEpochMs = today;
      toEpochMs = StudentAssignmentsViewModel.endOfDay(today);
    } else if (dateFilter === AssignmentDateFilter.TOMORROW) {
      let tomorrow = StudentAssignmentsViewModel.addDays(today, 1);
      fromEpochMs = tomorrow;
      toEpochMs = StudentAssignmentsViewModel.endOfDay(tomorrow);
    } else if (dateFilter === AssignmentDateFilter.THIS_WEEK) {
      fromEpochMs = today;
      toEpochMs = StudentAssignmentsViewModel.endOfWeek(today);
    }
    return {
      assignmentType: typeFilter,
      subjectCode: subjectCode,
      dateFilter: dateFilter,
      fromEpochMs: fromEpochMs,
      toEpochMs: toEpochMs,
      undatedOnly: undatedOnly,
      statuses: statuses
    };
  }

  private static startOfDay(epochMs: number): number {
    let value = new Date(epochMs);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate()).getTime();
  }

  private static endOfDay(dayStart: number): number {
    return StudentAssignmentsViewModel.addDays(dayStart, 1) - 1;
  }

  private static addDays(dayStart: number, days: number): number {
    let value = new Date(dayStart);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate() + days).getTime();
  }

  private static endOfWeek(todayStart: number): number {
    let weekday = new Date(todayStart).getDay();
    let mondayBased = weekday === 0 ? 7 : weekday;
    return StudentAssignmentsViewModel.addDays(todayStart, 8 - mondayBased) - 1;
  }
}
