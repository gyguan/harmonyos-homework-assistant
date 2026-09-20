import { http } from '@kit.NetworkKit';
import {
  PracticeAnswer,
  PracticeAttempt,
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeQuestion,
  PracticeQuestionOption,
  PracticeQuestionResult,
  PracticeQuestionType,
  PracticeResult
} from '../../domain/model/practice/PracticeModels';
import { BackendHttpClient } from './BackendHttpClient';

interface RemotePracticeOption { key: string; label: string; }
interface RemotePracticeQuestion {
  id: string; orderNo: number; type: string; stem: string;
  options: RemotePracticeOption[]; hints: string[]; tags: string[];
}
interface RemotePracticeAnswer { questionId: string; answerValue: string; answeredAtEpochMs: number; }
interface RemotePracticeAttempt {
  id: string; studentId: string; paperId: string; paperVersion: number; attemptNo: number;
  mode: string; status: string; startedAtEpochMs: number; submittedAtEpochMs: number;
  elapsedSeconds: number; answeredCount: number; questionCount: number;
  questions: RemotePracticeQuestion[]; answers: RemotePracticeAnswer[];
}
interface RemotePracticeQuestionResult {
  questionId: string; orderNo: number; stem: string; answerValue: string;
  correctAnswer: string; correct: boolean; score: number; explanation: string;
}
interface RemotePracticeResult {
  attemptId: string; paperId: string; paperVersion: number; attemptNo: number;
  score: number; maxScore: number; correctCount: number; wrongCount: number;
  elapsedSeconds: number; questions: RemotePracticeQuestionResult[];
}
interface StartAttemptBody { paperId: string; paperVersion: number; }
interface SaveAnswerBody { answerValue: string; }

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
    return {
      id: remote.id, studentId: remote.studentId, paperId: remote.paperId, paperVersion: remote.paperVersion,
      attemptNo: remote.attemptNo, mode: remote.mode as PracticeAttemptMode, status: remote.status as PracticeAttemptStatus,
      startedAtEpochMs: remote.startedAtEpochMs, submittedAtEpochMs: remote.submittedAtEpochMs,
      elapsedSeconds: remote.elapsedSeconds, answeredCount: remote.answeredCount, questionCount: remote.questionCount,
      questions: questions, answers: answers
    };
  }

  private mapResult(remote: RemotePracticeResult): PracticeResult {
    let questions: PracticeQuestionResult[] = [];
    for (let source of remote.questions) {
      questions.push({
        questionId: source.questionId, orderNo: source.orderNo, stem: source.stem, answerValue: source.answerValue,
        correctAnswer: source.correctAnswer, correct: source.correct, score: source.score, explanation: source.explanation
      });
    }
    return {
      attemptId: remote.attemptId, paperId: remote.paperId, paperVersion: remote.paperVersion,
      attemptNo: remote.attemptNo, score: remote.score, maxScore: remote.maxScore,
      correctCount: remote.correctCount, wrongCount: remote.wrongCount,
      elapsedSeconds: remote.elapsedSeconds, questions: questions
    };
  }
}
