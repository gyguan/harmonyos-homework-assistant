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
  private observedVersions: Map<string, number> = new Map<string, number>();
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
          let created = await HomeworkRemoteApi.instance.create(assignment);
          this.observedVersions.set(created.id, created.version);
          continue;
        }

        let lastObserved = this.observedVersions.get(assignment.id);
        // Missing or stale sync metadata means the server wins. This is intentionally conservative:
        // V0.x does not attempt CRDT/offline conflict merging.
        if (lastObserved !== undefined && lastObserved === existing.version) {
          try {
            let updated = await HomeworkRemoteApi.instance.update(assignment, lastObserved);
            this.observedVersions.set(updated.id, updated.version);
          } catch {
            // 409/transient failures are reconciled by the final server refresh.
          }
        }
      }

      let finalRemote = await HomeworkRemoteApi.instance.list(studentId);
      let merged: Assignment[] = [];
      for (let item of finalRemote) {
        this.observedVersions.set(item.id, item.version);
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
