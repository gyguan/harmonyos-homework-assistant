import { HomeworkStore } from '../../data/HomeworkStore';
import { Assignment } from '../../domain/model/HomeworkModels';
import { BackendSession } from './BackendSession';
import { HomeworkRemoteApi } from './HomeworkRemoteApi';
import { RemoteAssignment, RemoteAssignmentMapper } from './RemoteModels';
import { RemoteSubmissionApi } from './RemoteSubmissionApi';
import { RemoteSubmissionCache } from './RemoteSubmissionCache';

export class HomeworkSyncService {
  static readonly instance: HomeworkSyncService = new HomeworkSyncService();
  private running: boolean = false;
  private requested: boolean = false;
  private constructor() {}

  requestSync(): void {
    if (!BackendSession.instance.isConnected()) return;
    this.requested = true;
    if (!this.running) void this.flush();
  }

  async syncActiveStudent(): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    let studentId = HomeworkStore.instance.getActiveStudentId();
    try {
      let remote = await HomeworkRemoteApi.instance.list(studentId);
      let remoteById: Map<string, RemoteAssignment> = new Map<string, RemoteAssignment>();
      for (let item of remote) remoteById.set(item.id, item);

      let local = HomeworkStore.instance.getAssignments().slice();
      for (let assignment of local) {
        let existing = remoteById.get(assignment.id);
        if (existing === undefined) {
          // candidateId is present only for a real assignment published after parent confirmation.
          // Demo/seed assignments intentionally stay local and are never uploaded automatically.
          if (assignment.candidateId.length === 0) continue;
          await HomeworkRemoteApi.instance.create(assignment);
          continue;
        }

        // Only locally changed assignments may update the server, and only from the exact remote
        // version that was persisted when this assignment was last refreshed. A mismatch means
        // another device already advanced the server; the final refresh below deliberately wins.
        if (assignment.syncDirty && assignment.remoteVersion === existing.version) {
          try {
            await HomeworkRemoteApi.instance.update(assignment, assignment.remoteVersion);
          } catch {
            // 409/transient failures are reconciled by the final server refresh.
          }
        }
      }

      let finalRemote = await HomeworkRemoteApi.instance.list(studentId);
      let merged: Assignment[] = [];
      for (let item of finalRemote) {
        merged.push(RemoteAssignmentMapper.toLocal(item, HomeworkStore.instance.getAssignment(item.id)));
        try {
          RemoteSubmissionCache.instance.replace(item.id, await RemoteSubmissionApi.instance.list(item.id));
        } catch {
          // Submission metadata sync is best-effort and must never block homework sync.
        }
      }
      HomeworkStore.instance.replaceAssignmentsForActiveStudent(merged);
      return true;
    } catch {
      return false;
    }
  }

  private async flush(): Promise<void> {
    this.running = true;
    while (this.requested) {
      this.requested = false;
      await this.syncActiveStudent();
    }
    this.running = false;
  }
}
