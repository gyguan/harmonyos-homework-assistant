import {
  AppSettings,
  Assignment,
  CandidateAssignment,
  RawHomeworkImport,
  Submission,
  TutorSession
} from './HomeworkModels';

export interface HomeworkSnapshot {
  schemaVersion: number;
  settings: AppSettings;
  rawImports: RawHomeworkImport[];
  assignments: Assignment[];
  candidates: CandidateAssignment[];
  submissions: Submission[];
  tutorSessions: TutorSession[];
  submissionSequence: number;
}
