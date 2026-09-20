import {
  PracticeGrade,
  PracticePaper,
  PracticeSemester,
  PracticeSubject
} from '../model/practice/PracticeModels';

export interface PracticeContentProvider {
  listPapers(grade: PracticeGrade, subject: PracticeSubject, semester: PracticeSemester): Promise<PracticePaper[]>;
  getPaper(paperId: string, version: number): Promise<PracticePaper | null>;
}
