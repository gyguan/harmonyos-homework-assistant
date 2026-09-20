import {
  PracticeAnswer,
  PracticeAttempt,
  PracticeAttemptSummary,
  PracticeGrade,
  PracticeNote,
  PracticePaper,
  PracticeResult,
  PracticeSemester,
  PracticeSubject,
  PracticeTrackFilter
} from '../model/practice/PracticeModels';

export interface PracticeRepository {
  listPapers(grade: PracticeGrade, subject: PracticeSubject, semester: PracticeSemester, track: PracticeTrackFilter): Promise<PracticePaper[]>;
  getPaper(paperId: string, version: number): Promise<PracticePaper | null>;
  startAttempt(studentId: string, paperId: string, version: number): Promise<PracticeAttempt>;
  getAttempt(attemptId: string): Promise<PracticeAttempt>;
  listAttempts(studentId: string, paperId: string): Promise<PracticeAttemptSummary[]>;
  repeatAttempt(attemptId: string): Promise<PracticeAttempt>;
  retryWrongAttempt(attemptId: string): Promise<PracticeAttempt>;
  saveAnswer(attemptId: string, questionId: string, answerValue: string): Promise<PracticeAnswer>;
  saveNote(attemptId: string, questionId: string, content: string): Promise<PracticeNote>;
  deleteNote(attemptId: string, questionId: string): Promise<void>;
  submitAttempt(attemptId: string): Promise<PracticeResult>;
  getResult(attemptId: string): Promise<PracticeResult>;
}
