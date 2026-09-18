import { CandidateAssignment, RawHomeworkImport } from '../../domain/model/HomeworkModels';
import { HomeworkImportDraftRepository } from '../../domain/port/HomeworkImportDraftRepository';
import { DefaultHomeworkImportLocalDataSource, HomeworkImportLocalDataSource } from '../local/HomeworkImportLocalDataSource';

export class DefaultHomeworkImportDraftRepository implements HomeworkImportDraftRepository {
  static readonly instance: DefaultHomeworkImportDraftRepository = new DefaultHomeworkImportDraftRepository();
  private readonly local: HomeworkImportLocalDataSource = DefaultHomeworkImportLocalDataSource.instance;
  private constructor() {}

  getActiveStudentId(): string { return this.local.getActiveStudentId(); }
  getRawImport(): RawHomeworkImport { return this.local.getRawImport(); }
  getCandidates(): CandidateAssignment[] { return this.local.getCandidates().slice(); }
  replaceRawImport(input: RawHomeworkImport): void { this.local.replaceRawImport(input); }
  replaceCandidates(candidates: CandidateAssignment[]): void { this.local.replaceCandidates(candidates); }
  updateCandidate(candidate: CandidateAssignment): boolean { return this.local.updateCandidate(candidate); }
  addCandidate(candidate: CandidateAssignment): boolean { return this.local.addCandidate(candidate); }
  removeCandidate(candidateId: string): boolean { return this.local.removeCandidate(candidateId); }
  clearCandidates(): void { this.local.replaceCandidates([]); }
}
