import {
  PracticeGrade,
  PracticePaper,
  PracticeSubject
} from '../model/practice/PracticeModels';

export interface PracticeContentProvider {
  listPapers(grade: PracticeGrade, subject: PracticeSubject): Promise<PracticePaper[]>;
  getPaper(paperId: string, version: number): Promise<PracticePaper | null>;
}
