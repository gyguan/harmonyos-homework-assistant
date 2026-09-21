import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeAnswer,
  PracticeAttempt,
  PracticeNote,
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

  saveNote(attemptId: string, questionId: string, content: string): Promise<PracticeNote> {
    return this.repository.saveNote(attemptId, questionId, content);
  }

  deleteNote(attemptId: string, questionId: string): Promise<void> {
    return this.repository.deleteNote(attemptId, questionId);
  }

  submit(attemptId: string): Promise<PracticeResult> {
    return this.repository.submitAttempt(attemptId);
  }
}
