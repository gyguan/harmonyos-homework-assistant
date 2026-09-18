import { http } from '@kit.NetworkKit';
import { DefaultFamilyContextRepository } from '../../data/repository/DefaultFamilyContextRepository';
import { FamilyContextRepository } from '../../domain/port/FamilyContextRepository';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';

export interface TutorChatMessage {
  id: string;
  role: string;
  content: string;
  createdAt: string;
}

export interface TutorConversation {
  sessionId: string | null;
  available: boolean;
  notice: string;
  messages: TutorChatMessage[];
  hasMore: boolean;
  nextBeforeEpochMs: number;
}

interface AskPayload {
  text: string;
  guidanceFirst: boolean;
  directAnswerAllowed: boolean;
}

export class TutorRemoteApi {
  static readonly instance: TutorRemoteApi = new TutorRemoteApi();
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  private constructor() {}

  async load(assignmentId: string, beforeEpochMs: number = 0): Promise<TutorConversation> {
    if (!BackendSession.instance.isConnected()) return this.disconnected();
    try {
      let suffix = beforeEpochMs > 0 ? `?limit=40&before=${beforeEpochMs}` : '?limit=40';
      let response = await BackendHttpClient.instance.request(
        `/api/v1/assignments/${encodeURIComponent(assignmentId)}/tutor${suffix}`,
        http.RequestMethod.GET);
      if (response.statusCode !== 200) return this.unavailable('AI Tutor 暂时不可用');
      return JSON.parse(response.body) as TutorConversation;
    } catch {
      return this.unavailable('AI Tutor 暂时不可用');
    }
  }

  async ask(assignmentId: string, text: string): Promise<TutorConversation> {
    if (!BackendSession.instance.isConnected()) return this.disconnected();
    let settings = this.familyContext.getSettings();
    let payload: AskPayload = {
      text: text,
      guidanceFirst: settings.tutorGuidanceFirst,
      directAnswerAllowed: settings.directAnswerAllowed
    };
    try {
      let response = await BackendHttpClient.instance.request(`/api/v1/assignments/${encodeURIComponent(assignmentId)}/tutor/messages`, http.RequestMethod.POST, payload);
      if (response.statusCode !== 200) return this.unavailable('AI Tutor 暂时不可用');
      return JSON.parse(response.body) as TutorConversation;
    } catch {
      return this.unavailable('AI Tutor 暂时不可用');
    }
  }

  private disconnected(): TutorConversation {
    return this.unavailable('请家长先在“我的”中连接家庭云端，之后即可使用小伴辅导。');
  }

  private unavailable(notice: string): TutorConversation {
    return {
      sessionId: null, available: false, notice: notice, messages: [],
      hasMore: false, nextBeforeEpochMs: 0
    };
  }
}
