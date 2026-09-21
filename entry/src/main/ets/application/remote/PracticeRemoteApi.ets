import { http } from '@kit.NetworkKit';
import {
  PracticeAnswer,
  PracticeGrade,
  PracticeNote,
  PracticeAttempt,
  PracticeAttemptMode,
  PracticeAttemptSummary,
  PracticeAttemptStatus,
  PracticeQuestion,
  PracticeQuestionOption,
  PracticeQuestionResult,
  PracticeQuestionType,
  PracticePreviousAnswer,
  PracticePreviousNote,
  PracticeResult,
  PracticeSubject
} from '../../domain/model/practice/PracticeModels';
import { BackendHttpClient } from './BackendHttpClient';

interface RemotePracticeOption { key: string; label: string; }
interface RemotePracticeQuestion {
  id: string; orderNo: number; type: string; stem: string;
  options: RemotePracticeOption[]; hints: string[]; tags: string[];
}
interface RemotePracticeAnswer { questionId: string; answerValue: string; answeredAtEpochMs: number; }
interface RemotePracticeNote {
  questionId: string; content: string; createdAtEpochMs: number; updatedAtEpochMs: number;
}
interface RemotePracticePreviousAnswer { questionId: string; answerValue: string; correct: boolean; }
interface RemotePracticePreviousNote { questionId: string; content: string; }
interface RemotePracticeAttemptSummary {
  id: string; paperId: string; paperVersion: number; paperTitle: string; grade: string; subject: string;
  attemptNo: number; mode: string; status: string; sourceAttemptId: string; startedAtEpochMs: number;
  submittedAtEpochMs: number; elapsedSeconds: number; answeredCount: number; questionCount: number;
  noteCount: number; score: number; maxScore: number; correctCount: number; wrongCount: number;
}
interface RemotePracticeAttempt {
  id: string; studentId: string; paperId: string; paperVersion: number; attemptNo: number;
  mode: string; status: string; sourceAttemptId: string; startedAtEpochMs: number; submittedAtEpochMs: number;
  elapsedSeconds: number; answeredCount: number; questionCount: number; noteCount: number;
  questions: RemotePracticeQuestion[]; answers: RemotePracticeAnswer[]; notes: RemotePracticeNote[];
  previousAnswers: RemotePracticePreviousAnswer[]; previousNotes: RemotePracticePreviousNote[];
}
interface RemotePracticeQuestionResult {
  questionId: string; orderNo: number; stem: string; answerValue: string;
  correctAnswer: string; correct: boolean; score: number; explanation: string; noteContent: string;
}
interface RemotePracticeResult {
  attemptId: string; paperId: string; paperVersion: number; attemptNo: number; mode: string;
  score: number; maxScore: number; correctCount: number; wrongCount: number; noteCount: number;
  elapsedSeconds: number; questions: RemotePracticeQuestionResult[];
}
interface StartAttemptBody { paperId: string; paperVersion: number; }
interface SaveAnswerBody { answerValue: string; }
interface SaveNoteBody { content: string; }

export class PracticeRemoteApi {
  static readonly instance: PracticeRemoteApi = new PracticeRemoteApi();
  private constructor() {}

  async startAttempt(studentId: string, paperId: string, version: number): Promise<PracticeAttempt> {
    let body: StartAttemptBody = { paperId: paperId, paperVersion: version };
    let response = await BackendHttpClient.instance.requestFor(
      'practice.attempt.start', `/api/v1/students/${encodeURIComponent(studentId)}/practice/attempts`,
      http.RequestMethod.POST, body);
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`开始练习失败: ${response.statusCode}`);
    return this.mapAttempt(JSON.parse(response.body) as RemotePracticeAttempt);
  }

  async listAttempts(studentId: string, paperId: string = ''): Promise<PracticeAttemptSummary[]> {
    let suffix = paperId.length > 0 ? `?paperId=${encodeURIComponent(paperId)}` : '';
    let response = await BackendHttpClient.instance.requestFor(
      'practice.history.list',
      `/api/v1/students/${encodeURIComponent(studentId)}/practice/attempts${suffix}`,
      http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`读取练习历史失败: ${response.statusCode}`);
    }
    let remote = JSON.parse(response.body) as RemotePracticeAttemptSummary[];
    let result: PracticeAttemptSummary[] = [];
    for (let item of remote) result.push(this.mapSummary(item));
    return result;
  }

  async repeatAttempt(attemptId: string): Promise<PracticeAttempt> {
    let response = await BackendHttpClient.instance.requestFor(
      'practice.attempt.repeat',
      `/api/v1/practice/attempts/${encodeURIComponent(attemptId)}/repeat`,
      http.RequestMethod.POST);
    if (response.statusCode === 409) throw new Error('只有已交卷练习才能再练一遍');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`再次练习失败: ${response.statusCode}`);
    }
    return this.mapAttempt(JSON.parse(response.body) as RemotePracticeAttempt);
  }

  async retryWrongAttempt(attemptId: string): Promise<PracticeAttempt> {
    let response = await BackendHttpClient.instance.requestFor(
      'practice.attempt.wrongOnly',
      `/api/v1/practice/attempts/${encodeURIComponent(attemptId)}/wrong-only`,
      http.RequestMethod.POST);
    if (response.statusCode === 409) throw new Error('本次没有错题，无需专项重练');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`错题重练创建失败: ${response.statusCode}`);
    }
    return this.mapAttempt(JSON.parse(response.body) as RemotePracticeAttempt);
  }

  async getAttempt(attemptId: string): Promise<PracticeAttempt> {
    let response = await BackendHttpClient.instance.requestFor(
      'practice.attempt.get', `/api/v1/practice/attempts/${encodeURIComponent(attemptId)}`,
      http.RequestMethod.GET);
    if (response.statusCode === 404) throw new Error('练习记录不存在');
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`读取练习失败: ${response.statusCode}`);
    return this.mapAttempt(JSON.parse(response.body) as RemotePracticeAttempt);
  }

  async saveAnswer(attemptId: string, questionId: string, answerValue: string): Promise<PracticeAnswer> {
    let body: SaveAnswerBody = { answerValue: answerValue };
    let response = await BackendHttpClient.instance.requestFor(
      'practice.answer.save',
      `/api/v1/practice/attempts/${encodeURIComponent(attemptId)}/answers/${encodeURIComponent(questionId)}`,
      http.RequestMethod.PUT, body);
    if (response.statusCode === 409) throw new Error('本次练习已经交卷');
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`保存答案失败: ${response.statusCode}`);
    let remote = JSON.parse(response.body) as RemotePracticeAnswer;
    return { questionId: remote.questionId, answerValue: remote.answerValue, answeredAtEpochMs: remote.answeredAtEpochMs };
  }

  async saveNote(attemptId: string, questionId: string, content: string): Promise<PracticeNote> {
    let body: SaveNoteBody = { content: content };
    let response = await BackendHttpClient.instance.requestFor(
      'practice.note.save',
      `/api/v1/practice/attempts/${encodeURIComponent(attemptId)}/notes/${encodeURIComponent(questionId)}`,
      http.RequestMethod.PUT, body);
    if (response.statusCode === 409) throw new Error('本次练习已经交卷');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`保存笔记失败: ${response.statusCode}`);
    }
    let remote = JSON.parse(response.body) as RemotePracticeNote;
    return this.mapNote(remote);
  }

  async deleteNote(attemptId: string, questionId: string): Promise<void> {
    let response = await BackendHttpClient.instance.requestFor(
      'practice.note.delete',
      `/api/v1/practice/attempts/${encodeURIComponent(attemptId)}/notes/${encodeURIComponent(questionId)}`,
      http.RequestMethod.DELETE);
    if (response.statusCode === 409) throw new Error('本次练习已经交卷');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`删除笔记失败: ${response.statusCode}`);
    }
  }

  async submitAttempt(attemptId: string): Promise<PracticeResult> {
    let response = await BackendHttpClient.instance.requestFor(
      'practice.attempt.submit', `/api/v1/practice/attempts/${encodeURIComponent(attemptId)}/submit`,
      http.RequestMethod.POST);
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`交卷失败: ${response.statusCode}`);
    return this.mapResult(JSON.parse(response.body) as RemotePracticeResult);
  }

  async getResult(attemptId: string): Promise<PracticeResult> {
    let response = await BackendHttpClient.instance.requestFor(
      'practice.result.get', `/api/v1/practice/attempts/${encodeURIComponent(attemptId)}/result`,
      http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`读取练习结果失败: ${response.statusCode}`);
    return this.mapResult(JSON.parse(response.body) as RemotePracticeResult);
  }

  private mapAttempt(remote: RemotePracticeAttempt): PracticeAttempt {
    let questions: PracticeQuestion[] = [];
    for (let source of remote.questions) {
      let options: PracticeQuestionOption[] = [];
      for (let option of source.options) options.push({ key: option.key, label: option.label });
      questions.push({
        id: source.id, paperId: remote.paperId, paperVersion: remote.paperVersion, orderNo: source.orderNo,
        type: source.type as PracticeQuestionType, stem: source.stem, options: options,
        answerSpec: '', explanation: '', hints: source.hints.slice(), tags: source.tags.slice()
      });
    }
    let answers: PracticeAnswer[] = [];
    for (let answer of remote.answers) {
      answers.push({ questionId: answer.questionId, answerValue: answer.answerValue, answeredAtEpochMs: answer.answeredAtEpochMs });
    }
    let notes: PracticeNote[] = [];
    for (let note of remote.notes) notes.push(this.mapNote(note));
    let previousAnswers: PracticePreviousAnswer[] = [];
    for (let answer of remote.previousAnswers) {
      previousAnswers.push({ questionId: answer.questionId, answerValue: answer.answerValue, correct: answer.correct });
    }
    let previousNotes: PracticePreviousNote[] = [];
    for (let note of remote.previousNotes) {
      previousNotes.push({ questionId: note.questionId, content: note.content });
    }
    return {
      id: remote.id, studentId: remote.studentId, paperId: remote.paperId, paperVersion: remote.paperVersion,
      attemptNo: remote.attemptNo, mode: remote.mode as PracticeAttemptMode, status: remote.status as PracticeAttemptStatus,
      sourceAttemptId: remote.sourceAttemptId, startedAtEpochMs: remote.startedAtEpochMs, submittedAtEpochMs: remote.submittedAtEpochMs,
      elapsedSeconds: remote.elapsedSeconds, answeredCount: remote.answeredCount, questionCount: remote.questionCount,
      noteCount: remote.noteCount, questions: questions, answers: answers, notes: notes,
      previousAnswers: previousAnswers, previousNotes: previousNotes
    };
  }

  private mapSummary(remote: RemotePracticeAttemptSummary): PracticeAttemptSummary {
    return {
      id: remote.id,
      paperId: remote.paperId,
      paperVersion: remote.paperVersion,
      paperTitle: remote.paperTitle,
      grade: remote.grade as PracticeGrade,
      subject: remote.subject as PracticeSubject,
      attemptNo: remote.attemptNo,
      mode: remote.mode as PracticeAttemptMode,
      status: remote.status as PracticeAttemptStatus,
      sourceAttemptId: remote.sourceAttemptId,
      startedAtEpochMs: remote.startedAtEpochMs,
      submittedAtEpochMs: remote.submittedAtEpochMs,
      elapsedSeconds: remote.elapsedSeconds,
      answeredCount: remote.answeredCount,
      questionCount: remote.questionCount,
      noteCount: remote.noteCount,
      score: remote.score,
      maxScore: remote.maxScore,
      correctCount: remote.correctCount,
      wrongCount: remote.wrongCount
    };
  }

  private mapNote(remote: RemotePracticeNote): PracticeNote {
    return {
      questionId: remote.questionId,
      content: remote.content,
      createdAtEpochMs: remote.createdAtEpochMs,
      updatedAtEpochMs: remote.updatedAtEpochMs
    };
  }

  private mapResult(remote: RemotePracticeResult): PracticeResult {
    let questions: PracticeQuestionResult[] = [];
    for (let source of remote.questions) {
      questions.push({
        questionId: source.questionId, orderNo: source.orderNo, stem: source.stem, answerValue: source.answerValue,
        correctAnswer: source.correctAnswer, correct: source.correct, score: source.score,
        explanation: source.explanation, noteContent: source.noteContent
      });
    }
    return {
      attemptId: remote.attemptId, paperId: remote.paperId, paperVersion: remote.paperVersion,
      attemptNo: remote.attemptNo, mode: remote.mode as PracticeAttemptMode,
      score: remote.score, maxScore: remote.maxScore,
      correctCount: remote.correctCount, wrongCount: remote.wrongCount, noteCount: remote.noteCount,
      elapsedSeconds: remote.elapsedSeconds, questions: questions
    };
  }
}
