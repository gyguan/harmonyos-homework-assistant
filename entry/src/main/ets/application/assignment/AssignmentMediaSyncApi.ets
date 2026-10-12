import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from '../remote/BackendHttpClient';
import { BackendSession } from '../remote/BackendSession';

export enum AssignmentMediaSyncStatus {
  UNAVAILABLE = 'UNAVAILABLE',
  PENDING = 'PENDING',
  RUNNING = 'RUNNING',
  READY = 'READY',
  FAILED = 'FAILED'
}

export interface AssignmentMediaSyncItem {
  imageResourceId: string;
  startMs: number;
  endMs: number;
  confidence: number;
}

export interface AssignmentMediaSyncState {
  status: AssignmentMediaSyncStatus;
  available: boolean;
  confidence: number;
  durationMs: number;
  items: AssignmentMediaSyncItem[];
}

interface RemoteAssignmentMediaSyncItem {
  imageResourceId: string;
  startMs: number;
  endMs: number;
  confidence: number;
}

interface RemoteAssignmentMediaSyncState {
  status: string;
  available: boolean;
  confidence: number;
  durationMs: number;
  items: RemoteAssignmentMediaSyncItem[];
}

export class AssignmentMediaSyncApi {
  static readonly instance: AssignmentMediaSyncApi = new AssignmentMediaSyncApi();

  private constructor() {}

  async get(assignmentId: string): Promise<AssignmentMediaSyncState> {
    if (!BackendSession.instance.isConnected()) return this.unavailable();

    try {
      let path = '/api/v1/assignments/' + encodeURIComponent(assignmentId) + '/media-sync';
      let response = await BackendHttpClient.instance.requestFor(
        'assignment.media_sync.get', path, http.RequestMethod.GET);
      if (response.statusCode !== 200) return this.unavailable();

      let remote = JSON.parse(response.body) as RemoteAssignmentMediaSyncState;
      let items: AssignmentMediaSyncItem[] = [];
      if (remote.items !== undefined && remote.items !== null) {
        for (let item of remote.items) {
          items.push({
            imageResourceId: item.imageResourceId,
            startMs: Math.max(0, item.startMs),
            endMs: Math.max(0, item.endMs),
            confidence: Math.max(0, item.confidence)
          });
        }
      }
      return {
        status: this.status(remote.status),
        available: remote.available === true,
        confidence: Math.max(0, remote.confidence),
        durationMs: Math.max(0, remote.durationMs),
        items: items
      };
    } catch {
      return this.unavailable();
    }
  }

  private status(value: string): AssignmentMediaSyncStatus {
    if (value === AssignmentMediaSyncStatus.PENDING) return AssignmentMediaSyncStatus.PENDING;
    if (value === AssignmentMediaSyncStatus.RUNNING) return AssignmentMediaSyncStatus.RUNNING;
    if (value === AssignmentMediaSyncStatus.READY) return AssignmentMediaSyncStatus.READY;
    if (value === AssignmentMediaSyncStatus.FAILED) return AssignmentMediaSyncStatus.FAILED;
    return AssignmentMediaSyncStatus.UNAVAILABLE;
  }

  private unavailable(): AssignmentMediaSyncState {
    return {
      status: AssignmentMediaSyncStatus.UNAVAILABLE,
      available: false,
      confidence: 0,
      durationMs: 0,
      items: []
    };
  }
}
