import { AssignmentFilter } from '../model/AssignmentFilter';
import { Assignment, StudentProfile, TodaySummary } from '../model/HomeworkModels';

export interface AssignmentRepository {
  getActiveStudent(): StudentProfile;
  listCached(filter?: AssignmentFilter): Assignment[];
  query(filter: AssignmentFilter): Promise<Assignment[]>;
  getCached(assignmentId: string): Assignment | null;
  getCachedSummary(): TodaySummary;
  refresh(): Promise<boolean>;
}
