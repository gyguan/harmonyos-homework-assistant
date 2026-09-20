import {
  PracticeGrade,
  PracticePaper,
  PracticeSubject
} from '../model/practice/PracticeModels';

export interface PracticeRepository {
  listPapers(grade: PracticeGrade, subject: PracticeSubject): Promise<PracticePaper[]>;
  getPaper(paperId: string, version: number): Promise<PracticePaper | null>;
}
