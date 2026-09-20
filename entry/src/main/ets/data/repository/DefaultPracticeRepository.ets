import { BackendSession } from '../../application/remote/BackendSession';
import { PracticeRemoteApi } from '../../application/remote/PracticeRemoteApi';
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
} from '../../domain/model/practice/PracticeModels';
import { PracticeContentProvider } from '../../domain/port/PracticeContentProvider';
import { PracticeRepository } from '../../domain/port/PracticeRepository';
import { PresetPracticeContentProvider } from '../practice/PresetPracticeContentProvider';

export class DefaultPracticeRepository implements PracticeRepository {
  static readonly instance: DefaultPracticeRepository = new DefaultPracticeRepository(
    PresetPracticeContentProvider.instance, PracticeRemoteApi.instance);

  private readonly contentProvider: PracticeContentProvider;
  private readonly remoteApi: PracticeRemoteApi;

  constructor(contentProvider: PracticeContentProvider, remoteApi: PracticeRemoteApi) {
    this.contentProvider = contentProvider;
    this.remoteApi = remoteApi;
  }

  listPapers(
    grade: PracticeGrade,
    subject: PracticeSubject,
    semester: PracticeSemester,
    track: PracticeTrackFilter
  ): Promise<PracticePaper[]> {
    return this.contentProvider.listPapers(grade, subject, semester, track);
  }

  getPaper(paperId: string, version: number): Promise<PracticePaper | null> {
    return this.contentProvider.getPaper(paperId, version);
  }

  startAttempt(studentId: string, paperId: string, version: number): Promise<PracticeAttempt> {
    this.requireConnected();
    return this.remoteApi.startAttempt(studentId, paperId, version);
  }

  getAttempt(attemptId: string): Promise<PracticeAttempt> {
    this.requireConnected();
    return this.remoteApi.getAttempt(attemptId);
  }

  listAttempts(studentId: string, paperId: string = ''): Promise<PracticeAttemptSummary[]> {
    this.requireConnected();
    return this.remoteApi.listAttempts(studentId, paperId);
  }

  repeatAttempt(attemptId: string): Promise<PracticeAttempt> {
    this.requireConnected();
    return this.remoteApi.repeatAttempt(attemptId);
  }

  retryWrongAttempt(attemptId: string): Promise<PracticeAttempt> {
    this.requireConnected();
    return this.remoteApi.retryWrongAttempt(attemptId);
  }

  saveAnswer(attemptId: string, questionId: string, answerValue: string): Promise<PracticeAnswer> {
    this.requireConnected();
    return this.remoteApi.saveAnswer(attemptId, questionId, answerValue);
  }

  saveNote(attemptId: string, questionId: string, content: string): Promise<PracticeNote> {
    this.requireConnected();
    return this.remoteApi.saveNote(attemptId, questionId, content);
  }

  deleteNote(attemptId: string, questionId: string): Promise<void> {
    this.requireConnected();
    return this.remoteApi.deleteNote(attemptId, questionId);
  }

  submitAttempt(attemptId: string): Promise<PracticeResult> {
    this.requireConnected();
    return this.remoteApi.submitAttempt(attemptId);
  }

  getResult(attemptId: string): Promise<PracticeResult> {
    this.requireConnected();
    return this.remoteApi.getResult(attemptId);
  }

  private requireConnected(): void {
    if (!BackendSession.instance.isConnected()) throw new Error('当前离线，连接家庭云端后才能开始练习');
  }
}
