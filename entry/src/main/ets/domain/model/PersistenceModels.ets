import { AppSettings, Assignment, CandidateAssignment, Submission, TutorSession } from './HomeworkModels';

export interface HomeworkSnapshot {
  schemaVersion: number;
  settings: AppSettings;
  assignments: Assignment[];
  candidates: CandidateAssignment[];
  submissions: Submission[];
  tutorSessions: TutorSession[];
  submissionSequence: number;
}
