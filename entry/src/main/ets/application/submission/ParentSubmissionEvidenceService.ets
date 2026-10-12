import { BackendSession } from '../remote/BackendSession';
import {
  RemoteSubmission,
  RemoteSubmissionApi,
  RemoteSubmissionResource
} from '../remote/RemoteSubmissionApi';
import { RemoteSubmissionCache } from '../remote/RemoteSubmissionCache';
import { Submission } from '../../domain/model/HomeworkModels';
import { HomeworkSubmissionService } from './HomeworkSubmissionService';

export interface ParentSubmissionEvidence {
  submissionId: string;
  assignmentId: string;
  submittedAtText: string;
  remoteResources: RemoteSubmissionResource[];
  localPhotoUris: string[];
  localAudioUri: string;
  localAudioDurationMs: number;
}

export class ParentSubmissionEvidenceService {
  static readonly instance: ParentSubmissionEvidenceService = new ParentSubmissionEvidenceService();

  private constructor() {}

  cachedLatest(assignmentId: string): ParentSubmissionEvidence | null {
    let remote = RemoteSubmissionCache.instance.get(assignmentId);
    if (remote.length > 0) return this.fromRemote(remote[0]);

    let local = HomeworkSubmissionService.instance.listCached(assignmentId);
    if (local.length === 0) return null;
    return this.fromLocal(local[local.length - 1]);
  }

  async refreshLatest(assignmentId: string): Promise<ParentSubmissionEvidence | null> {
    if (BackendSession.instance.isConnected()) {
      try {
        let remote = await RemoteSubmissionApi.instance.latest(assignmentId);
        RemoteSubmissionCache.instance.replace(assignmentId, remote === null ? [] : [remote]);
      } catch {
        // Evidence refresh is best-effort. Keep the last synchronized submission metadata.
      }
    }
    return this.cachedLatest(assignmentId);
  }

  private fromRemote(value: RemoteSubmission): ParentSubmissionEvidence {
    return {
      submissionId: value.id,
      assignmentId: value.assignmentId,
      submittedAtText: this.formatRemoteTime(value.submittedAt),
      remoteResources: value.resources.slice(),
      localPhotoUris: [],
      localAudioUri: '',
      localAudioDurationMs: 0
    };
  }

  private fromLocal(value: Submission): ParentSubmissionEvidence {
    return {
      submissionId: value.id,
      assignmentId: value.assignmentId,
      submittedAtText: value.submittedAtText,
      remoteResources: [],
      localPhotoUris: value.photoUris.slice(),
      localAudioUri: value.audioUri === undefined ? '' : value.audioUri,
      localAudioDurationMs: value.durationMs === undefined ? 0 : value.durationMs
    };
  }

  private formatRemoteTime(value: string): string {
    let parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) return value;
    let month = this.pad(parsed.getMonth() + 1);
    let day = this.pad(parsed.getDate());
    let hour = this.pad(parsed.getHours());
    let minute = this.pad(parsed.getMinutes());
    return `${parsed.getFullYear()}-${month}-${day} ${hour}:${minute}`;
  }

  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
