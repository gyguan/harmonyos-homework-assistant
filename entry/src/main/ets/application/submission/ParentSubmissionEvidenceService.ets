import { BackendSession } from '../remote/BackendSession';
import {
  RemoteSubmission,
  RemoteSubmissionApi,
  RemoteSubmissionPhoto
} from '../remote/RemoteSubmissionApi';
import { RemoteSubmissionCache } from '../remote/RemoteSubmissionCache';
import { Submission } from '../../domain/model/HomeworkModels';
import { HomeworkSubmissionService } from './HomeworkSubmissionService';

export interface ParentSubmissionEvidence {
  submissionId: string;
  assignmentId: string;
  submittedAtText: string;
  remotePhotos: RemoteSubmissionPhoto[];
  localPhotoUris: string[];
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
        let remote = await RemoteSubmissionApi.instance.list(assignmentId);
        RemoteSubmissionCache.instance.replace(assignmentId, remote);
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
      remotePhotos: value.photos.slice(),
      localPhotoUris: []
    };
  }

  private fromLocal(value: Submission): ParentSubmissionEvidence {
    return {
      submissionId: value.id,
      assignmentId: value.assignmentId,
      submittedAtText: value.submittedAtText,
      remotePhotos: [],
      localPhotoUris: value.photoUris.slice()
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
