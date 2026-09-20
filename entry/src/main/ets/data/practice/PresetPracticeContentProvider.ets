import {
  PracticeGrade,
  PracticePaper,
  PracticePaperStatus,
  PracticeSemester,
  PracticeSubject
} from '../../domain/model/practice/PracticeModels';
import { PracticeContentProvider } from '../../domain/port/PracticeContentProvider';
import { PresetPracticeCatalog } from './PresetPracticeCatalog';

export class PresetPracticeContentProvider implements PracticeContentProvider {
  static readonly instance: PresetPracticeContentProvider = new PresetPracticeContentProvider();

  private constructor() {}

  async listPapers(
    grade: PracticeGrade,
    subject: PracticeSubject,
    semester: PracticeSemester
  ): Promise<PracticePaper[]> {
    let result: PracticePaper[] = [];
    for (let paper of PresetPracticeCatalog.papers()) {
      if (paper.grade !== grade || paper.subject !== subject ||
        paper.status !== PracticePaperStatus.PUBLISHED) continue;
      if (semester !== PracticeSemester.ALL &&
        paper.semester !== PracticeSemester.ALL &&
        paper.semester !== semester) continue;
      result.push(this.clonePaper(paper));
    }
    return result;
  }

  async getPaper(paperId: string, version: number): Promise<PracticePaper | null> {
    for (let paper of PresetPracticeCatalog.papers()) {
      if (paper.id === paperId && paper.version === version && paper.status === PracticePaperStatus.PUBLISHED) {
        return this.clonePaper(paper);
      }
    }
    return null;
  }

  private clonePaper(source: PracticePaper): PracticePaper {
    return {
      id: source.id,
      version: source.version,
      grade: source.grade,
      subject: source.subject,
      semester: source.semester,
      title: source.title,
      description: source.description,
      difficulty: source.difficulty,
      questionCount: source.questionCount,
      estimatedMinutes: source.estimatedMinutes,
      tags: source.tags.slice(),
      sourceType: source.sourceType,
      status: source.status
    };
  }
}
