import {
  AssignmentDateFilter,
  AssignmentTypeFilter
} from '../../../domain/model/AssignmentFilter';
import { Assignment, AssignmentStatus, StudentProfile } from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';
import { AssignmentFilterFactory } from '../../../domain/service/AssignmentFilterFactory';

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
    return this.repository.listCached(AssignmentFilterFactory.create(typeFilter, subjectCode, dateFilter, statuses));
  }

  async query(typeFilter: AssignmentTypeFilter, subjectCode: string, dateFilter: AssignmentDateFilter,
    statuses: AssignmentStatus[] = []): Promise<Assignment[]> {
    return this.repository.query(AssignmentFilterFactory.create(typeFilter, subjectCode, dateFilter, statuses));
  }

  assignmentsOnDay(subjectCode: string, dayEpochMs: number,
    statuses: AssignmentStatus[] = []): Assignment[] {
    return this.repository.listCached(AssignmentFilterFactory.forDay(subjectCode, dayEpochMs, statuses));
  }

  queryOnDay(subjectCode: string, dayEpochMs: number,
    statuses: AssignmentStatus[] = []): Promise<Assignment[]> {
    return this.repository.query(AssignmentFilterFactory.forDay(subjectCode, dayEpochMs, statuses));
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
}
