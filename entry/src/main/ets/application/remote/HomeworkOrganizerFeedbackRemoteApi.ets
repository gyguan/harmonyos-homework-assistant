import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';

export interface HomeworkFeedbackType {
  code: string;
  label: string;
  description: string;
  requiresComment: boolean;
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
