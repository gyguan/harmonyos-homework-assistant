import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';

export interface HomeworkFeedbackType {
  code: string;
  label: string;
  description: string;
  requiresComment: boolean;
  canBecomeExperience: boolean;
}

export interface HomeworkFeedbackInput {
  clientRequestId: string;
  candidateId: string;
  batchId: string;
  teacherName: string;
  subject: string;
  feedbackTypeCode: string;
  sourceLabel: string;
  sourceExcerpt: string;
  originalTitle: string;
  currentTitle: string;
  details: string;
}

export interface HomeworkFeedbackReceipt {
  id: string;
  candidateId: string;
  feedbackTypeCode: string;
  processingStatus: string;
  createdAt: string;
}

export interface HomeworkTeacherExperienceSummary {
  id: string;
  teacherName: string;
  subject: string;
  cue: string;
  interpretation: string;
  origin: string;
  active: boolean;
  sourceFeedbackId: string | null;
}

export interface HomeworkExperiencePromotion {
  cue: string;
  interpretation: string;
}

export class HomeworkOrganizerFeedbackRemoteApi {
  static readonly instance: HomeworkOrganizerFeedbackRemoteApi = new HomeworkOrganizerFeedbackRemoteApi();
  private constructor() {}

  async listTypes(studentId: string): Promise<HomeworkFeedbackType[]> {
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.feedback.types',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/feedback/types`,
      http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('反馈选项加载失败，请检查网络后重试');
    }
    let parsed = JSON.parse(response.body) as HomeworkFeedbackType[];
    if (!Array.isArray(parsed)) throw new Error('反馈选项数据格式不正确');
    return parsed;
  }

  async listExperiences(studentId: string): Promise<HomeworkTeacherExperienceSummary[]> {
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.experiences.list',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/teacher-experiences`,
      http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('老师经验列表加载失败');
    }
    return JSON.parse(response.body) as HomeworkTeacherExperienceSummary[];
  }

  async setExperienceActive(studentId: string, experienceId: string,
    active: boolean): Promise<HomeworkTeacherExperienceSummary> {
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.experiences.active',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/teacher-experiences/${encodeURIComponent(experienceId)}/active`,
      http.RequestMethod.PUT, { active: active });
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('调整经验状态失败');
    }
    return JSON.parse(response.body) as HomeworkTeacherExperienceSummary;
  }

  async promote(studentId: string, feedbackId: string,
    input: HomeworkExperiencePromotion): Promise<HomeworkTeacherExperienceSummary> {
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.feedback.promote',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/feedback/${encodeURIComponent(feedbackId)}/promote`,
      http.RequestMethod.POST, input);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('老师经验保存失败，请核对老师、触发词及释义');
    }
    return JSON.parse(response.body) as HomeworkTeacherExperienceSummary;
  }

  async submit(studentId: string, input: HomeworkFeedbackInput): Promise<HomeworkFeedbackReceipt> {
    let response = await BackendHttpClient.instance.requestFor(
      'homework.organize.feedback.create',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/feedback`,
      http.RequestMethod.POST, input);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('反馈保存失败，请检查网络后重试');
    }
    return JSON.parse(response.body) as HomeworkFeedbackReceipt;
  }
}
