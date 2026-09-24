import {
  AssignmentDateFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus } from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';
import { AssignmentDateRange } from '../../../domain/service/AssignmentDateRange';
import { AssignmentFilterFactory } from '../../../domain/service/AssignmentFilterFactory';

export class StudentAssignmentsViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository) {
    this.repository = repository;
  }

  assignments(typeFilter: AssignmentTypeFilter, subjectCode: string,
    dateFilter: AssignmentDateFilter, statuses: AssignmentStatus[] = []): Assignment[] {
    return this.repository.listCached(AssignmentFilterFactory.create(typeFilter, subjectCode, dateFilter, statuses));
  }

  assignmentsOnDay(typeFilter: AssignmentTypeFilter, subjectCode: string, dayEpochMs: number): Assignment[] {
    let source = this.assignments(typeFilter, subjectCode, AssignmentDateFilter.ALL);
    let targetDay = AssignmentDateRange.startOfDay(dayEpochMs);
    let result: Assignment[] = [];
    for (let item of source) {
      if (item.dueAtEpochMs <= 0) continue;
      if (AssignmentDateRange.startOfDay(item.dueAtEpochMs) === targetDay) result.push(item);
    }
    return result;
  }

  async query(typeFilter: AssignmentTypeFilter, subjectCode: string,
    dateFilter: AssignmentDateFilter, statuses: AssignmentStatus[] = []): Promise<Assignment[]> {
    return this.repository.query(AssignmentFilterFactory.create(typeFilter, subjectCode, dateFilter, statuses));
  }

  queryOnDay(subjectCode: string, dayEpochMs: number,
    statuses: AssignmentStatus[] = []): Promise<Assignment[]> {
    return this.repository.query(AssignmentFilterFactory.forDay(subjectCode, dayEpochMs, statuses));
  }

  allCount(): number {
    return this.assignments(AssignmentTypeFilter.ALL, 'ALL', AssignmentDateFilter.ALL).length;
  }

  assignment(assignmentId: string): Assignment | null {
    return this.repository.getCached(assignmentId);
  }

  async refresh(): Promise<boolean> {
    return this.repository.refresh();
  }
}
