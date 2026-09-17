import { AssignmentAction } from '../model/AssignmentAction';
import { AssignmentFilter } from '../model/AssignmentFilter';
import { AssignmentReviewDecision } from '../model/AssignmentReviewDecision';
import { Assignment, StudentProfile, TodaySummary } from '../model/HomeworkModels';

export interface AssignmentRepository {
  getActiveStudent(): StudentProfile;
  listCached(filter?: AssignmentFilter): Assignment[];
  query(filter: AssignmentFilter): Promise<Assignment[]>;
  getCached(assignmentId: string): Assignment | null;
  getCachedSummary(): TodaySummary;
  create(assignment: Assignment): Promise<Assignment>;
  performAction(assignmentId: string, action: AssignmentAction): Promise<Assignment>;
  review(assignmentId: string, decision: AssignmentReviewDecision, note: string): Promise<Assignment>;
  applyAuthoritative(assignment: Assignment): void;
  refresh(): Promise<boolean>;
}
