import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeAttempt,
  PracticeAttemptSummary,
  PracticePaper,
  PracticeResult
} from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';

export class PracticeResultViewModel {
  private readonly repository: PracticeRepository;
  private readonly familyContext: FamilyContextRepository;

  constructor(
    repository: PracticeRepository = DefaultPracticeRepository.instance,
    familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance
  ) {
    this.repository = repository;
    this.familyContext = familyContext;
  }

  load(attemptId: string): Promise<PracticeResult> {
    return this.repository.getResult(attemptId);
  }

  async paperTitle(result: PracticeResult): Promise<string> {
    try {
      let attempts: PracticeAttemptSummary[] =
        await this.repository.listAttempts(this.familyContext.getActiveStudentId(), result.paperId);
      for (let item of attempts) {
        if (item.id === result.attemptId && item.paperTitle.length > 0) return item.paperTitle;
      }
    } catch {
      // Historical summary is a convenience source for retired paper versions.
      // If it is temporarily unavailable, fall back to the local published catalog below.
    }

    let paper: PracticePaper | null = await this.repository.getPaper(result.paperId, result.paperVersion);
    if (paper !== null && paper.title.length > 0) return paper.title;
    return result.paperId;
  }

  repeat(attemptId: string): Promise<PracticeAttempt> {
    return this.repository.repeatAttempt(attemptId);
  }

  retryWrong(attemptId: string): Promise<PracticeAttempt> {
    return this.repository.retryWrongAttempt(attemptId);
  }

  percent(result: PracticeResult): number {
    if (result.maxScore <= 0) return 0;
    return Math.round(result.score * 100 / result.maxScore);
  }

  elapsedText(seconds: number): string {
    let minutes = Math.floor(seconds / 60);
    let rest = seconds % 60;
    return `${minutes}分${rest}秒`;
  }
}
