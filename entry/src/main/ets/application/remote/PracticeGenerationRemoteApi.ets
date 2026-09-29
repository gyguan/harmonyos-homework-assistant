import { http } from '@kit.NetworkKit';
import {
  PracticeAudienceCandidate,
  PracticeDifficulty,
  PracticeGenerationDraft,
  PracticeGenerationDraftQuestion,
  PracticeGenerationRequest,
  PracticeGenerationResult,
  PracticeGrade,
  PracticePaper,
  PracticePaperStatus,
  PracticePublishPurpose,
  PracticePublishResult,
  PracticePublishScope,
  PracticeQuestionOption,
  PracticeQuestionType,
  PracticeSemester,
  PracticeSourceType,
  PracticeSubject,
  PracticeTrack
} from '../../domain/model/practice/PracticeModels';
import { BackendHttpClient } from './BackendHttpClient';

interface RemoteOption { key: string; label: string; }
interface RemoteDraftQuestion {
  id: string;
  orderNo: number;
  type: string;
  stem: string;
  options: RemoteOption[];
  answerSpec: string;
  explanation: string;
  hints: string[];
  tags: string[];
}
interface RemoteDraftPaper {
  id: string;
  version: number;
  grade: string;
  subject: string;
  semester: string;
  track: string;
  title: string;
  description: string;
  difficulty: string;
  questionCount: number;
  estimatedMinutes: number;
  tags: string[];
  sourceType: string;
  questions: RemoteDraftQuestion[];
}
interface RemoteAudienceCandidate {
  studentId: string;
  studentName: string;
  grade: string;
  semester: string;
  compatible: boolean;
  reason: string;
}
interface RemoteGeneration {
  generationId: string;
  status: string;
  paper: RemoteDraftPaper | null;
  errorMessage: string;
  audienceCandidates: RemoteAudienceCandidate[];
}
interface RemotePaper {
  id: string;
  version: number;
  grade: string;
  subject: string;
  semester: string;
  track: string;
  title: string;
  description: string;
  difficulty: string;
  questionCount: number;
  estimatedMinutes: number;
  tags: string[];
  sourceType: string;
}
interface RemotePublish {
  generationId: string;
  status: string;
  paper: RemotePaper;
  targetStudentIds: string[];
}
interface RemoteErrorBody { message?: string; }
interface GenerateBody {
  subject: string;
  track: string;
  difficulty: string;
  questionCount: number;
  requirement: string;
}
interface PublishBody {
  scope: string;
  targetStudentIds: string[];
  purpose: string;
}

export class PracticeGenerationRemoteApi {
  static readonly instance: PracticeGenerationRemoteApi = new PracticeGenerationRemoteApi();
  private constructor() {}

  async generate(studentId: string, input: PracticeGenerationRequest): Promise<PracticeGenerationResult> {
    let body: GenerateBody = {
      subject: input.subject,
      track: input.track,
      difficulty: input.difficulty,
      questionCount: input.questionCount,
      requirement: input.requirement
    };
    let response = await BackendHttpClient.instance.requestFor(
      'practice.generation.create',
      `/api/v1/students/${encodeURIComponent(studentId)}/practice/generations`,
      http.RequestMethod.POST,
      body);
    if (response.statusCode === 400) throw new Error(this.message(response.body, '生成条件不完整'));
    if (response.statusCode === 503) throw new Error(this.message(response.body, 'AI出题暂时不可用'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`AI出题失败: ${response.statusCode}`);
    }
    return this.mapGeneration(JSON.parse(response.body) as RemoteGeneration);
  }

  async get(generationId: string): Promise<PracticeGenerationResult> {
    let response = await BackendHttpClient.instance.requestFor(
      'practice.generation.get',
      `/api/v1/practice/generations/${encodeURIComponent(generationId)}`,
      http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`读取AI练习草稿失败: ${response.statusCode}`);
    }
    return this.mapGeneration(JSON.parse(response.body) as RemoteGeneration);
  }

  async publish(
    generationId: string,
    scope: PracticePublishScope,
    targetStudentIds: string[],
    purpose?: PracticePublishPurpose
  ): Promise<PracticePublishResult> {
    let body: PublishBody = {
      scope: scope,
      targetStudentIds: targetStudentIds.slice(),
      purpose: purpose === undefined ? PracticePublishPurpose.STANDARD : purpose
    };
    let response = await BackendHttpClient.instance.requestFor(
      'practice.generation.publish',
      `/api/v1/practice/generations/${encodeURIComponent(generationId)}/publish`,
      http.RequestMethod.POST,
      body);
    if (response.statusCode === 409) throw new Error(this.message(response.body, '当前练习草稿不能发布'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`发布AI练习失败: ${response.statusCode}`);
    }
    let remote = JSON.parse(response.body) as RemotePublish;
    return {
      paper: this.mapPaper(remote.paper),
      targetStudentIds: remote.targetStudentIds.slice()
    };
  }

  private mapGeneration(remote: RemoteGeneration): PracticeGenerationResult {
    let candidates: PracticeAudienceCandidate[] = [];
    for (let item of remote.audienceCandidates) {
      candidates.push({
        studentId: item.studentId,
        studentName: item.studentName,
        grade: item.grade,
        semester: item.semester,
        compatible: item.compatible,
        reason: item.reason
      });
    }
    return {
      generationId: remote.generationId,
      status: remote.status,
      paper: remote.paper === null ? null : this.mapDraft(remote.paper),
      errorMessage: remote.errorMessage,
      audienceCandidates: candidates
    };
  }

  private mapDraft(remote: RemoteDraftPaper): PracticeGenerationDraft {
    let questions: PracticeGenerationDraftQuestion[] = [];
    for (let source of remote.questions) {
      let options: PracticeQuestionOption[] = [];
      for (let option of source.options) options.push({ key: option.key, label: option.label });
      questions.push({
        id: source.id,
        orderNo: source.orderNo,
        type: source.type as PracticeQuestionType,
        stem: source.stem,
        options: options,
        answerSpec: source.answerSpec,
        explanation: source.explanation,
        hints: source.hints.slice(),
        tags: source.tags.slice()
      });
    }
    return {
      id: remote.id,
      version: remote.version,
      grade: remote.grade as PracticeGrade,
      subject: remote.subject as PracticeSubject,
      semester: remote.semester as PracticeSemester,
      track: remote.track as PracticeTrack,
      title: remote.title,
      description: remote.description,
      difficulty: remote.difficulty as PracticeDifficulty,
      questionCount: remote.questionCount,
      estimatedMinutes: remote.estimatedMinutes,
      tags: remote.tags.slice(),
      sourceType: remote.sourceType as PracticeSourceType,
      questions: questions
    };
  }

  private mapPaper(remote: RemotePaper): PracticePaper {
    return {
      id: remote.id,
      version: remote.version,
      grade: remote.grade as PracticeGrade,
      subject: remote.subject as PracticeSubject,
      semester: remote.semester as PracticeSemester,
      track: remote.track as PracticeTrack,
      title: remote.title,
      description: remote.description,
      difficulty: remote.difficulty as PracticeDifficulty,
      questionCount: remote.questionCount,
      estimatedMinutes: remote.estimatedMinutes,
      tags: remote.tags.slice(),
      sourceType: remote.sourceType as PracticeSourceType,
      status: PracticePaperStatus.PUBLISHED
    };
  }

  private message(body: string, fallback: string): string {
    try {
      let parsed = JSON.parse(body) as RemoteErrorBody;
      return parsed.message ?? fallback;
    } catch {
      return fallback;
    }
  }
}
