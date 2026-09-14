import { Assignment, CandidateAssignment, Submission } from './HomeworkModels';

export interface HomeworkSnapshot {
  schemaVersion: number;
  assignments: Assignment[];
  candidates: CandidateAssignment[];
  submissions: Submission[];
  submissionSequence: number;
}
