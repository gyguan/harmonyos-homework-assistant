import { HomeworkStore } from '../HomeworkStore';
import { CandidateAssignment, RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../domain/port/HomeworkImportDraftRepository';

export class DefaultHomeworkImportDraftRepository implements HomeworkImportDraftRepository {
  static readonly instance: DefaultHomeworkImportDraftRepository = new DefaultHomeworkImportDraftRepository();
  private constructor() {}

  getActiveStudentId(): string { return HomeworkStore.instance.getActiveStudentId(); }
  getRawImport(): RawHomeworkImport { return HomeworkStore.instance.getRawImport(); }
  getCandidates(): CandidateAssignment[] { return HomeworkStore.instance.getCandidates().slice(); }
  replaceRawImport(input: RawHomeworkImport): void { HomeworkStore.instance.replaceRawImport(input); }
  replaceCandidates(candidates: CandidateAssignment[]): void { HomeworkStore.instance.replaceCandidates(candidates); }
  updateCandidate(candidate: CandidateAssignment): boolean { return HomeworkStore.instance.updateCandidate(candidate); }
  addCandidate(candidate: CandidateAssignment): boolean { return HomeworkStore.instance.addCandidate(candidate); }
  removeCandidate(candidateId: string): boolean { return HomeworkStore.instance.removeCandidate(candidateId); }
  clearCandidates(): void { HomeworkStore.instance.replaceCandidates([]); }
}
