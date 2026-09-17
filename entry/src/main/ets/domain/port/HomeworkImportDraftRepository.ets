import { CandidateAssignment, RawHomeworkImport } from '../model/HomeworkModels';

export interface HomeworkImportDraftRepository {
  getActiveStudentId(): string;
  getRawImport(): RawHomeworkImport;
  getCandidates(): CandidateAssignment[];
  replaceRawImport(input: RawHomeworkImport): void;
  replaceCandidates(candidates: CandidateAssignment[]): void;
  updateCandidate(candidate: CandidateAssignment): boolean;
  addCandidate(candidate: CandidateAssignment): boolean;
  removeCandidate(candidateId: string): boolean;
  clearCandidates(): void;
}
