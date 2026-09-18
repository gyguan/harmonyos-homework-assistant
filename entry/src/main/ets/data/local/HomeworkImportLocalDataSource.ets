import { HomeworkStore } from '../HomeworkStore';
import { CandidateAssignment, RawHomeworkImport } from '../../domain/model/HomeworkModels';

export interface HomeworkImportLocalDataSource {
  getActiveStudentId(): string;
  getRawImport(): RawHomeworkImport;
  getCandidates(): CandidateAssignment[];
  replaceRawImport(input: RawHomeworkImport): void;
  replaceCandidates(candidates: CandidateAssignment[]): void;
  updateCandidate(candidate: CandidateAssignment): boolean;
  addCandidate(candidate: CandidateAssignment): boolean;
  removeCandidate(candidateId: string): boolean;
}

export class DefaultHomeworkImportLocalDataSource implements HomeworkImportLocalDataSource {
  static readonly instance: DefaultHomeworkImportLocalDataSource =
    new DefaultHomeworkImportLocalDataSource();

  private constructor() {}

  getActiveStudentId(): string {
    return HomeworkStore.instance.getActiveStudentId();
  }

  getRawImport(): RawHomeworkImport {
    return HomeworkStore.instance.getRawImport();
  }

  getCandidates(): CandidateAssignment[] {
    return HomeworkStore.instance.getCandidates();
  }

  replaceRawImport(input: RawHomeworkImport): void {
    HomeworkStore.instance.replaceRawImport(input);
  }

  replaceCandidates(candidates: CandidateAssignment[]): void {
    HomeworkStore.instance.replaceCandidates(candidates);
  }

  updateCandidate(candidate: CandidateAssignment): boolean {
    return HomeworkStore.instance.updateCandidate(candidate);
  }

  addCandidate(candidate: CandidateAssignment): boolean {
    return HomeworkStore.instance.addCandidate(candidate);
  }

  removeCandidate(candidateId: string): boolean {
    return HomeworkStore.instance.removeCandidate(candidateId);
  }
}
