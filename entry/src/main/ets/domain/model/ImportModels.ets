import { CandidateAssignment } from './HomeworkModels';

export interface ExtractedHomeworkText {
  importId: string;
  sourceLabel: string;
  text: string;
}

export interface HomeworkImportPipelineResult {
  extracted: ExtractedHomeworkText;
  candidates: CandidateAssignment[];
}

export interface HomeworkImageImportResult {
  selected: boolean;
  candidateCount: number;
  recognizedText: string;
}
