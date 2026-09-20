import {
  AssignmentDateFilter,
  AssignmentFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus, StudentProfile } from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';

export class ParentProgressViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository) {
    this.repository = repository;
  }

  student(): StudentProfile {
    return this.repository.getActiveStudent();
  }

  assignments(typeFilter: AssignmentTypeFilter, subjectCode: string, dateFilter: AssignmentDateFilter,
    statuses: AssignmentStatus[] = []): Assignment[] {
    return this.repository.listCached(this.buildFilter(typeFilter, subjectCode, dateFilter, statuses));
  }

  async query(typeFilter: AssignmentTypeFilter, subjectCode: string, dateFilter: AssignmentDateFilter,
    statuses: AssignmentStatus[] = []): Promise<Assignment[]> {
    return this.repository.query(this.buildFilter(typeFilter, subjectCode, dateFilter, statuses));
  }

  assignment(assignmentId: string): Assignment | null {
    return this.repository.getCached(assignmentId);
  }

  deleteAssignments(assignmentIds: string[]): Promise<number> {
    return this.repository.deleteAssignments(assignmentIds);
  }

  async refresh(): Promise<boolean> {
    return this.repository.refresh();
  }

  private buildFilter(typeFilter: AssignmentTypeFilter, subjectCode: string, dateFilter: AssignmentDateFilter,
    statuses: AssignmentStatus[]): AssignmentFilter {
    let fromEpochMs = 0;
    let toEpochMs = 0;
    let undatedOnly = dateFilter === AssignmentDateFilter.UNDATED;
    let today = ParentProgressViewModel.startOfDay(Date.now());
    if (dateFilter === AssignmentDateFilter.TODAY) {
      fromEpochMs = today;
      toEpochMs = ParentProgressViewModel.endOfDay(today);
    } else if (dateFilter === AssignmentDateFilter.TOMORROW) {
      let tomorrow = ParentProgressViewModel.addDays(today, 1);
      fromEpochMs = tomorrow;
      toEpochMs = ParentProgressViewModel.endOfDay(tomorrow);
    } else if (dateFilter === AssignmentDateFilter.THIS_WEEK) {
      fromEpochMs = today;
      toEpochMs = ParentProgressViewModel.endOfWeek(today);
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
    return ParentProgressViewModel.addDays(dayStart, 1) - 1;
  }

  private static addDays(dayStart: number, days: number): number {
    let value = new Date(dayStart);
    return new Date(value.getFullYear(), value.getMonth(), value.getDate() + days).getTime();
  }

  private static endOfWeek(todayStart: number): number {
    let weekday = new Date(todayStart).getDay();
    let mondayBased = weekday === 0 ? 7 : weekday;
    return ParentProgressViewModel.addDays(todayStart, 8 - mondayBased) - 1;
  }
}
