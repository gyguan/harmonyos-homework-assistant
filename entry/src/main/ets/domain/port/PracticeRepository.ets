import {
  PracticeAnswer,
  PracticeAttempt,
  PracticeAttemptSummary,
  PracticeGrade,
  PracticePaper,
  PracticeResult,
  PracticeSubject
} from '../model/practice/PracticeModels';

export interface PracticeRepository {
  listPapers(grade: PracticeGrade, subject: PracticeSubject): Promise<PracticePaper[]>;
  getPaper(paperId: string, version: number): Promise<PracticePaper | null>;
  startAttempt(studentId: string, paperId: string, version: number): Promise<PracticeAttempt>;
  getAttempt(attemptId: string): Promise<PracticeAttempt>;
  listAttempts(studentId: string, paperId: string): Promise<PracticeAttemptSummary[]>;
  repeatAttempt(attemptId: string): Promise<PracticeAttempt>;
  saveAnswer(attemptId: string, questionId: string, answerValue: string): Promise<PracticeAnswer>;
  submitAttempt(attemptId: string): Promise<PracticeResult>;
  getResult(attemptId: string): Promise<PracticeResult>;
}
