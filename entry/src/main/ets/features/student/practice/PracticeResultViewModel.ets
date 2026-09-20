import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import { PracticeAttempt, PracticeResult } from '../../../domain/model/practice/PracticeModels';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';

export class PracticeResultViewModel {
  private readonly repository: PracticeRepository;

  constructor(repository: PracticeRepository = DefaultPracticeRepository.instance) {
    this.repository = repository;
  }

  load(attemptId: string): Promise<PracticeResult> {
    return this.repository.getResult(attemptId);
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
