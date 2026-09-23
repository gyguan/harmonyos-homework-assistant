import { http } from '@kit.NetworkKit';
import { CandidateAssignment, Subject } from '../../domain/model/HomeworkModels';
import { ExtractedHomeworkText } from '../../domain/model/ImportModels';
import { BackendHttpClient } from './BackendHttpClient';
import { BackendSession } from './BackendSession';

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

export class HomeworkOrganizerRemoteApi {
  static readonly instance: HomeworkOrganizerRemoteApi = new HomeworkOrganizerRemoteApi();
  private constructor() {}

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
      let result: CandidateAssignment[] = [];
      for (let i = 0; i < parsed.assignments.length; i++) {
        let remote = parsed.assignments[i];
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
    } catch {
      return null;
    }
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
