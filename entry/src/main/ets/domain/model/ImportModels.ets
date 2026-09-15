import { CandidateAssignment } from './HomeworkModels';

export enum HomeworkOrganizerMode {
  AI = 'AI',
  LOCAL = 'LOCAL'
}

export interface ExtractedHomeworkText {
  importId: string;
  studentId: string;
  sourceLabel: string;
  text: string;
}

export interface HomeworkImportPipelineResult {
  extracted: ExtractedHomeworkText;
  candidates: CandidateAssignment[];
  organizerMode: HomeworkOrganizerMode;
}

export interface HomeworkTextImportResult {
  candidateCount: number;
  organizerMode: HomeworkOrganizerMode;
}

export interface HomeworkImageImportResult {
  selected: boolean;
  candidateCount: number;
  recognizedText: string;
  organizerMode: HomeworkOrganizerMode;
}
