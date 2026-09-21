import {
  PracticeGrade,
  PracticePaper,
  PracticeSemester,
  PracticeSubject,
  PracticeTrackFilter
} from '../model/practice/PracticeModels';

export interface PracticeContentProvider {
  listPapers(grade: PracticeGrade, subject: PracticeSubject, semester: PracticeSemester, track: PracticeTrackFilter): Promise<PracticePaper[]>;
  getPaper(paperId: string, version: number): Promise<PracticePaper | null>;
}
