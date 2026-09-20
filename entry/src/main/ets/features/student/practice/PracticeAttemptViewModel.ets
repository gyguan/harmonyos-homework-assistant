import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeAnswer,
  PracticeAttempt,
  PracticeResult
} from '../../../domain/model/practice/PracticeModels';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';

export class PracticeAttemptViewModel {
  private readonly repository: PracticeRepository;

  constructor(repository: PracticeRepository = DefaultPracticeRepository.instance) {
    this.repository = repository;
  }

  load(attemptId: string): Promise<PracticeAttempt> {
    return this.repository.getAttempt(attemptId);
  }

  save(attemptId: string, questionId: string, answerValue: string): Promise<PracticeAnswer> {
    return this.repository.saveAnswer(attemptId, questionId, answerValue);
  }

  submit(attemptId: string): Promise<PracticeResult> {
    return this.repository.submitAttempt(attemptId);
  }
}
