import { http } from '@kit.NetworkKit';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';
import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';
import { HomeworkImageEncoder } from '../../infrastructure/ai/HomeworkImageEncoder';

interface OrganizePayload {
  text: string;
  sourceLabel: string;
}

interface RemoteCandidate {
  subject: string;
  title: string;
  instruction: string;
  textbookRef: string;
  dueText: string;
  expectedMinutes: number;
  sourceExcerpt: string;
  confidence: number;
}

interface OrganizeResponse {
  assignments: RemoteCandidate[];
  mode: string;
}

interface ImageOrganizePayload {
  imageBase64: string;
  contentType: string;
  sourceLabel: string;
  text: string;
}

interface ImageOrganizeResponse {
  assignments: RemoteCandidate[];
  mode: string;
  recognizedText: string;
}

interface OrganizerErrorResponse { message: string; }

export interface OrganizedHomeworkImage {
  candidates: CandidateAssignment[];
  recognizedText: string;
}

export class HomeworkOrganizerRemoteApi {
  static readonly instance: HomeworkOrganizerRemoteApi = new HomeworkOrganizerRemoteApi();
  private constructor() {}

  async organizeImage(input: ExtractedHomeworkText, imageRef: string): Promise<OrganizedHomeworkImage> {
    if (!BackendSession.instance.isConnected()) throw new Error('请先连接后端，或点击识别图片文字');
    let encoded = await HomeworkImageEncoder.encode(imageRef);
    let payload: ImageOrganizePayload = {
      imageBase64: encoded.imageBase64,
      contentType: encoded.contentType,
      sourceLabel: input.sourceLabel,
      text: input.text
    };
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.image',
      `/api/v1/students/${encodeURIComponent(input.studentId)}/homework/organize-image`,
      http.RequestMethod.POST, payload, true, 120000);
    if (response.statusCode === 401) throw new Error('登录已失效，请重新登录后重试');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      let message = 'AI图片解析失败，可点击识别图片文字后重试';
      try {
        let error = JSON.parse(response.body) as OrganizerErrorResponse;
        if (typeof error.message === 'string' && error.message.length > 0) message = error.message;
      } catch {
        // A gateway may return a non-JSON error; preserve a user-facing retry message.
      }
      throw new Error(message);
    }
    let parsed = JSON.parse(response.body) as ImageOrganizeResponse;
    if (parsed.mode !== 'AI_IMAGE' || typeof parsed.recognizedText !== 'string' ||
      parsed.recognizedText.trim().length === 0 || !Array.isArray(parsed.assignments)) {
      throw new Error('AI图片解析结果不完整，可点击识别图片文字后重试');
    }
    let candidates = this.toCandidates(input, parsed.assignments);
    if (candidates.length !== parsed.assignments.length) {
      throw new Error('AI返回的作业科目或标题无效，请重试或点击识别图片文字');
    }
    return { candidates: candidates, recognizedText: parsed.recognizedText.trim() };
  }

  async organize(input: ExtractedHomeworkText): Promise<CandidateAssignment[] | null> {
    if (!BackendSession.instance.isConnected()) {
      return null;
    }
    try {
      let payload: OrganizePayload = {
        text: input.text,
        sourceLabel: input.sourceLabel
      };
      let response = await BackendHttpClient.instance.requestFor(
        'homework.organize',
        `/api/v1/students/${encodeURIComponent(input.studentId)}/homework/organize`,
        http.RequestMethod.POST,
        payload
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      let parsed = JSON.parse(response.body) as OrganizeResponse;
      return this.toCandidates(input, parsed.assignments);
    } catch {
      return null;
    }
  }

  private toCandidates(input: ExtractedHomeworkText, assignments: RemoteCandidate[]): CandidateAssignment[] {
    let result: CandidateAssignment[] = [];
    for (let i = 0; i < assignments.length; i++) {
      let remote = assignments[i];
      let subject = this.subject(remote.subject);
      if (subject === null || remote.title.trim().length === 0) {
        continue;
      }
      let confidence = remote.confidence;
      if (confidence < 0) confidence = 0;
      if (confidence > 1) confidence = 1;
      result.push({
        id: `ai-${input.importId}-${i + 1}`,
        studentId: input.studentId,
        subject: subject,
        title: remote.title.trim(),
        instruction: this.value(remote.instruction, remote.title),
        textbookRef: this.value(remote.textbookRef, '待家长确认'),
        dueText: this.value(remote.dueText, '今天'),
        expectedMinutes: this.expectedMinutes(remote.expectedMinutes),
        sourceEvidence: {
          sourceLabel: input.sourceLabel,
          excerpt: this.value(remote.sourceExcerpt, remote.title)
        },
        confidence: confidence
      });
    }
    return result;
  }

  private subject(value: string): Subject | null {
    if (value === Subject.CHINESE) return Subject.CHINESE;
    if (value === Subject.MATH) return Subject.MATH;
    if (value === Subject.ENGLISH) return Subject.ENGLISH;
    if (value === Subject.READING) return Subject.READING;
    if (value === Subject.READ_ALOUD) return Subject.READ_ALOUD;
    if (value === Subject.SPORTS) return Subject.SPORTS;
    if (value === Subject.PRACTICE) return Subject.PRACTICE;
    if (value === Subject.INTEREST) return Subject.INTEREST;
    if (value === Subject.OTHER) return Subject.OTHER;
    return null;
  }

  private expectedMinutes(value: number): number {
    if (!Number.isFinite(value) || value <= 0) return 20;
    return Math.max(5, Math.min(120, Math.round(value)));
  }

  private value(value: string, fallback: string): string {
    if (value.trim().length === 0) return fallback;
    return value.trim();
  }
}
