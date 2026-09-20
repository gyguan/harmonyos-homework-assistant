import {
  PracticeGrade,
  PracticePaper,
  PracticeSubject
} from '../../domain/model/practice/PracticeModels';
import { PracticeContentProvider } from '../../domain/port/PracticeContentProvider';
import { PracticeRepository } from '../../domain/port/PracticeRepository';
import { PresetPracticeContentProvider } from '../practice/PresetPracticeContentProvider';

export class DefaultPracticeRepository implements PracticeRepository {
  static readonly instance: DefaultPracticeRepository = new DefaultPracticeRepository(
    PresetPracticeContentProvider.instance
  );

  private readonly contentProvider: PracticeContentProvider;

  constructor(contentProvider: PracticeContentProvider) {
    this.contentProvider = contentProvider;
  }

  listPapers(grade: PracticeGrade, subject: PracticeSubject): Promise<PracticePaper[]> {
    return this.contentProvider.listPapers(grade, subject);
  }

  getPaper(paperId: string, version: number): Promise<PracticePaper | null> {
    return this.contentProvider.getPaper(paperId, version);
  }
}
