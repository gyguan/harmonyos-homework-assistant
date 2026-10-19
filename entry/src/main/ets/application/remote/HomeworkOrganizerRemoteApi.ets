import { http } from '@kit.NetworkKit';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';
import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';
import { HomeworkImageEncoder } from '../../infrastructure/ai/HomeworkImageEncoder';
import { AssignmentTaskDate } from '../../domain/service/AssignmentTaskDate';

interface OrganizePayload {
  text: string;
  sourceLabel: string;
}

interface RemoteCandidate {
  subject: string;
  title: string;
  instruction: string;
  textbookRef: string;
  taskDate: string;
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

/** 仅保存本次 AI 原始标题供家长确认后比较，不包含孩子姓名或图片原件。 */
interface OrganizerOriginalCandidate {
  title: string;
  subject: string;
  sourceExcerpt: string;
}

interface OrganizerConfirmedEdit {
  teacherName: string;
  subject: string;
  sourceExcerpt: string;
  beforeTitle: string;
  afterTitle: string;
}

export interface OrganizedHomeworkImage {
  candidates: CandidateAssignment[];
  recognizedText: string;
}

export class HomeworkOrganizerRemoteApi {
  static readonly instance: HomeworkOrganizerRemoteApi = new HomeworkOrganizerRemoteApi();
  private readonly originalById: Map<string, OrganizerOriginalCandidate> = new Map<string, OrganizerOriginalCandidate>();
  private constructor() {}

  /** AI 原始标题仅在本次确认会话内保存，反馈时作为纠错前的证据。 */
  originalTitle(candidateId: string, fallback: string): string {
    let item = this.originalById.get(candidateId);
    return item === undefined ? fallback : item.title;
  }

  /** 家长成功发布后静默记录真正发生的标题纠错；上报失败不影响已发布作业。 */
  async reportConfirmedEdits(candidates: CandidateAssignment[]): Promise<void> {
    if (candidates.length === 0) return;
    let studentId = candidates[0].studentId;
    let teacherNames: string[] = [];
    let first = candidates[0];
    let raw = first.sourceEvidence.rawText === undefined ? '' : first.sourceEvidence.rawText;
    let combined = first.sourceEvidence.sourceLabel + '\n' + raw;
    let matches = combined.match(/[\\u4e00-\\u9fa5]{1,4}老师/g);
    if (matches !== null) {
      for (let name of matches) {
        if (teacherNames.indexOf(name) < 0) teacherNames.push(name);
      }
    }
    // 一个批次出现多位老师，或者根本没写老师姓名时，不推测归属。
    let teacherName = teacherNames.length === 1 ? teacherNames[0] : '';
    for (let candidate of candidates) {
      let previous = this.originalById.get(candidate.id);
      this.originalById.delete(candidate.id);
      if (previous === undefined || candidate.studentId !== studentId ||
        previous.title === candidate.title || teacherName.length === 0) continue;
      let excerpt = previous.sourceExcerpt.trim();
      if (excerpt.length === 0) continue;
      let payload: OrganizerConfirmedEdit = {
        teacherName: teacherName,
        subject: candidate.subject,
        sourceExcerpt: excerpt.substring(0, 120),
        beforeTitle: previous.title.substring(0, 400),
        afterTitle: candidate.title.substring(0, 400)
      };
      try {
        await BackendHttpClient.instance.requestFor(
          'homework.organize.feedback',
          `/api/v1/students/${encodeURIComponent(studentId)}/homework/teacher-experiences/confirmed-edit`,
          http.RequestMethod.POST, payload);
      } catch {
        // 学习是可选增强，不能把已成功发布的作业判为失败。
      }
    }
  }

  async organizeImage(input: ExtractedHomeworkText, imageRef: string): Promise<OrganizedHomeworkImage> {
    if (!BackendSession.instance.isConnected()) throw new Error('请先连接后端后再解析作业图片');
    let totalStarted = Date.now();
    let encodeStarted = Date.now();
    let encoded = await HomeworkImageEncoder.encode(imageRef);
    let encodeMs = Date.now() - encodeStarted;
    let payload: ImageOrganizePayload = {
      imageBase64: encoded.imageBase64,
      contentType: encoded.contentType,
      sourceLabel: input.sourceLabel,
      text: input.text
    };
    let requestStarted = Date.now();
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.image',
      `/api/v1/students/${encodeURIComponent(input.studentId)}/homework/organize-image`,
      http.RequestMethod.POST, payload, true, 120000);
    let requestMs = Date.now() - requestStarted;
    console.info(`[AI-PERF] homework_image encodeMs=${encodeMs} requestMs=${requestMs} totalMs=${Date.now() - totalStarted} imageBytes=${encoded.encodedBytes}`);
    if (response.statusCode === 401) throw new Error('登录已失效，请重新登录后重试');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      let message = 'AI图片解析失败，请换一张清晰图片后重试';
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
      !Array.isArray(parsed.assignments) ||
      (parsed.assignments.length > 0 && parsed.recognizedText.trim().length === 0)) {
      throw new Error('AI图片解析结果不完整，请换一张清晰图片后重试');
    }
    let candidates = this.toCandidates(input, parsed.assignments, parsed.recognizedText.trim());
    if (candidates.length !== parsed.assignments.length) {
      throw new Error('AI返回的作业科目或标题无效，请重试');
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

  private toCandidates(input: ExtractedHomeworkText, assignments: RemoteCandidate[],
    rawTextOverride?: string): CandidateAssignment[] {
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
      let candidateId = `ai-${input.importId}-${i + 1}`;
      this.originalById.set(candidateId, {
        title: remote.title.trim(),
        subject: subject,
        sourceExcerpt: this.value(remote.sourceExcerpt, remote.title)
      });
      if (this.originalById.size > 100) {
        let oldest = this.originalById.keys().next().value;
        if (oldest !== undefined) this.originalById.delete(oldest);
      }
      result.push({
        id: candidateId,
        studentId: input.studentId,
        subject: subject,
        title: remote.title.trim(),
        instruction: this.value(remote.instruction, remote.title),
        textbookRef: this.value(remote.textbookRef, '待家长确认'),
        taskDate: AssignmentTaskDate.resolve(this.value(remote.taskDate, AssignmentTaskDate.today())),
        expectedMinutes: this.expectedMinutes(remote.expectedMinutes),
        sourceEvidence: {
          sourceLabel: input.sourceLabel,
          excerpt: this.value(remote.sourceExcerpt, remote.title),
          rawText: rawTextOverride === undefined ? input.text : rawTextOverride
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
