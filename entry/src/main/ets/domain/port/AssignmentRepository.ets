import { Assignment, StudentProfile, TodaySummary } from '../model/HomeworkModels';

export interface AssignmentRepository {
  getActiveStudent(): StudentProfile;
  listCached(): Assignment[];
  getCachedSummary(): TodaySummary;
  refresh(): Promise<boolean>;
}
