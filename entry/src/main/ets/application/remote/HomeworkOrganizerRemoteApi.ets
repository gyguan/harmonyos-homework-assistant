import { http } from '@kit.NetworkKit';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';
import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';
import { HomeworkImageEncoder } from '../../infrastructure/ai/HomeworkImageEncoder';
import { AssignmentTaskDate } from '../../domain/service/AssignmentTaskDate';

interface OrganizePayload {
  importId: string;
  text: string;
  sourceLabel: string;
  teacherName: string;
}

interface OrganizerSourceBlock {
  id: string;
  text: string;
}

interface OrganizerSourceDocument {
  schemaVersion: number;
  inputKind: string;
  originalText: string;
  blocks: OrganizerSourceBlock[];
}

interface OrganizerQualityFlag {
  code: string;
  sourceBlockIds: string[];
  assignmentIndexes: number[];
}

interface RemoteCandidate {
  sourceBlockIds?: string[];
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
  sourceDocument?: OrganizerSourceDocument;
  qualityFlags?: OrganizerQualityFlag[];
  needsReview?: boolean;
  assignments: RemoteCandidate[];
  mode: string;
}

interface ImageOrganizePayload {
  importId: string;
  imageBase64: string;
  contentType: string;
  sourceLabel: string;
  text: string;
  teacherName: string;
}

interface ImageOrganizeResponse {
  sourceDocument?: OrganizerSourceDocument;
  qualityFlags?: OrganizerQualityFlag[];
  needsReview?: boolean;
  assignments: RemoteCandidate[];
  mode: string;
  recognizedText: string;
}

interface OrganizerErrorResponse { message: string; }

/** 仅保存本次 AI 原始标题供家长确认后比较，不包含孩子姓名或图片原件。 */
interface OrganizerOriginalCandidate {
  title: string;
  subject: string;
  instruction: string;
  textbookRef: string;
  taskDate: string;
  expectedMinutes: number;
  sourceExcerpt: string;
  studentId: string;
  batchId: string;
  teacherName: string;
}

interface OrganizerReviewDifference {
  candidateId: string;
  changeType: string;
  fieldName: string;
  beforeValue: string;
  afterValue: string;
  sourceExcerpt: string;
}

interface OrganizerOriginalCandidateResponse {
  candidateId: string;
  teacherName: string;
  title: string;
  subject: string;
  instruction: string;
  textbookRef: string;
  taskDate: string;
  expectedMinutes: number;
  sourceExcerpt: string;
}

interface OrganizerFinalizePayload {
  batchId: string;
  publishedCandidateIds: string[];
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

  /** Retrieve server originals after an app restart; never fabricate missing AI evidence. */
  async restoreOriginals(studentId: string, batchId: string): Promise<void> {
    if (studentId.length === 0 || batchId.length === 0) return;
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.snapshots',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/ai-snapshots/${encodeURIComponent(batchId)}`,
      http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) return;
    let rows = JSON.parse(response.body) as OrganizerOriginalCandidateResponse[];
    if (!Array.isArray(rows)) return;
    for (let row of rows) {
      if (typeof row.candidateId !== 'string' || row.candidateId.length === 0) continue;
      this.originalById.set(row.candidateId, {
        title: row.title,
        subject: row.subject,
        instruction: row.instruction,
        textbookRef: row.textbookRef,
        taskDate: row.taskDate,
        expectedMinutes: row.expectedMinutes,
        sourceExcerpt: row.sourceExcerpt,
        studentId: studentId,
        batchId: batchId,
        teacherName: row.teacherName
      });
    }
  }

  /** The server compares original snapshot with actual persisted published assignments. */
  async reportConfirmedReview(candidates: CandidateAssignment[]): Promise<void> {
    if (candidates.length === 0) return;
    let studentId = candidates[0].studentId;
    let batchId = candidates[0].sourceEvidence.batchId;
    if (batchId === undefined || batchId.length === 0) return;
    let ids: string[] = [];
    for (let item of candidates) {
      if (item.studentId !== studentId || item.sourceEvidence.batchId !== batchId) return;
      ids.push(item.id);
    }
    let payload: OrganizerFinalizePayload = {
      batchId: batchId,
      publishedCandidateIds: ids
    };
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.review-differences.finalize',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/review-differences/finalize`,
      http.RequestMethod.POST, payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('作业已发布，差异分析上传失败');
    }
    for (let entry of this.originalById.entries()) {
      if (entry[1].studentId === studentId && entry[1].batchId === batchId) {
        this.originalById.delete(entry[0]);
      }
    }
  }

  /** 家长成功发布后静默记录真正发生的标题纠错；上报失败不影响已发布作业。 */
  async reportConfirmedEdits(candidates: CandidateAssignment[]): Promise<void> {
    if (candidates.length === 0) return;
    let studentId = candidates[0].studentId;
    let teacherNames: string[] = [];
    let first = candidates[0];
    let raw = first.sourceEvidence.rawText === undefined ? '' : first.sourceEvidence.rawText;
    let combined = first.sourceEvidence.sourceLabel + '\n' + raw;
    let matches = combined.match(/[\u4e00-\u9fa5]{1,4}老师/g);
    if (matches !== null) {
      for (let name of matches) {
        if (teacherNames.indexOf(name) < 0) teacherNames.push(name);
      }
    }
    // 一个批次出现多位老师，或者根本没写老师姓名时，不推测归属。
    let teacherName = teacherNames.length === 1 ? teacherNames[0] : '';
    let explicitlyBound = first.sourceEvidence.teacherName === undefined ? '' :
      first.sourceEvidence.teacherName.trim();
    if (explicitlyBound.length > 0) teacherName = explicitlyBound;
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
      importId: input.importId,
      imageBase64: encoded.imageBase64,
      contentType: encoded.contentType,
      sourceLabel: input.sourceLabel,
      text: input.text,
      teacherName: input.teacherName === undefined ? '' : input.teacherName
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
      (parsed.assignments.length > 0 && parsed.recognizedText.trim().length === 0 && parsed.needsReview !== true)) {
      throw new Error('AI图片解析结果不完整，请换一张清晰图片后重试');
    }
    let candidates = this.toCandidates(input, parsed.assignments, parsed.recognizedText.trim(), parsed.qualityFlags, parsed.sourceDocument, parsed.needsReview);
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
        importId: input.importId,
        text: input.text,
        sourceLabel: input.sourceLabel,
        teacherName: input.teacherName === undefined ? '' : input.teacherName
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
      return this.toCandidates(input, parsed.assignments, undefined, parsed.qualityFlags, parsed.sourceDocument, parsed.needsReview);
    } catch {
      return null;
    }
  }

  private toCandidates(input: ExtractedHomeworkText, assignments: RemoteCandidate[],
    rawTextOverride?: string, flags?: OrganizerQualityFlag[], document?: OrganizerSourceDocument, needsReview?: boolean): CandidateAssignment[] {
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
        instruction: this.value(remote.instruction, remote.title),
        textbookRef: this.value(remote.textbookRef, '待家长确认'),
        taskDate: AssignmentTaskDate.resolve(this.value(remote.taskDate, AssignmentTaskDate.today())),
        expectedMinutes: this.expectedMinutes(remote.expectedMinutes),
        sourceExcerpt: this.value(remote.sourceExcerpt, remote.title),
        studentId: input.studentId,
        batchId: input.importId,
        teacherName: input.teacherName === undefined ? '' : input.teacherName
      });
      if (this.originalById.size > 100) {
        // 避免 IteratorResult.value 在严格 ArkTS 下被推断为 any/unknown。
        for (let oldestKey of this.originalById.keys()) {
          this.originalById.delete(oldestKey);
          break;
        }
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
          reviewNotice: this.reviewNotice(flags, document, i, needsReview),
          sourceBlockIds: remote.sourceBlockIds === undefined ? undefined : remote.sourceBlockIds.slice(),
          sourceLabel: input.sourceLabel,
          excerpt: this.value(remote.sourceExcerpt, remote.title),
          teacherName: input.teacherName === undefined ? '' : input.teacherName,
          rawText: rawTextOverride === undefined ? input.text : rawTextOverride
        },
        confidence: confidence
      });
    }
    return result;
  }

  private reviewNotice(flags: OrganizerQualityFlag[] | undefined, document: OrganizerSourceDocument | undefined,
    index: number, needsReview: boolean | undefined): string {
    if (needsReview !== true) return '';
    let notices: string[] = [];
    if (flags !== undefined) {
      for (let flag of flags) {
        if (flag.assignmentIndexes.length > 0 && flag.assignmentIndexes.indexOf(index) < 0) continue;
        let reason: string = '内容仍有不确定之处，请核对原文';
        if (flag.code === 'POSSIBLE_OMISSION') reason = '可能遗漏作业';
        if (flag.code === 'UNSUPPORTED_NUMBER' || flag.code === 'UNSUPPORTED_DATE') reason = '数量、页码或日期需要核对';
        if (flag.code === 'UNREADABLE_SOURCE') reason = '有看不清的原文';
        if (flag.code === 'TASK_WITHOUT_EVIDENCE' || flag.code === 'UNKNOWN_SOURCE_REFERENCE') reason = '这项作业缺少可核对的原文';
        if (flag.code.indexOf('REVIEW_') === 0) reason = 'AI复核未能确认，请核对后发布';
        let excerpt: string = '';
        if (document !== undefined) {
          for (let block of document.blocks) {
            if (flag.sourceBlockIds.indexOf(block.id) >= 0 && block.text.length > 0) {
              excerpt = block.text.substring(0, 80);
              break;
            }
          }
        }
        let notice: string = excerpt.length > 0 ? `${reason}：${excerpt}` : reason;
        if (notices.indexOf(notice) < 0) notices.push(notice);
        if (notices.length >= 3) break;
      }
    }
    return notices.length > 0 ? notices.join('；') : '请核对老师原文后再发布';
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
