import { HomeworkStore } from '../../data/HomeworkStore';
import { Assignment } from '../../domain/model/HomeworkModels';
import { BackendSession } from './BackendSession';
import { HomeworkRemoteApi } from './HomeworkRemoteApi';
import { RemoteAssignment, RemoteAssignmentMapper } from './RemoteModels';

export class HomeworkSyncService {
  static readonly instance: HomeworkSyncService = new HomeworkSyncService();
  private running: boolean = false;
  private requested: boolean = false;
  // Sync metadata deliberately stays outside the domain model. If this app process has never
  // observed a server version for an assignment, the server wins on first reconciliation.
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
          let created = await HomeworkRemoteApi.instance.create(assignment);
          this.observedVersions.set(created.id, created.version);
          continue;
        }

        let lastObserved = this.observedVersions.get(assignment.id);
        // Only write when this process is still based on the same remote version it saw before.
        // A missing/mismatched version means another device may be newer, so server data wins.
        if (lastObserved !== undefined && lastObserved === existing.version) {
          try {
            let updated = await HomeworkRemoteApi.instance.update(assignment, lastObserved);
            this.observedVersions.set(updated.id, updated.version);
          } catch {
            // A 409 or transient write failure is resolved by the final server refresh below.
          }
        }
      }

      let finalRemote = await HomeworkRemoteApi.instance.list(studentId);
      let merged: Assignment[] = [];
      for (let item of finalRemote) {
        this.observedVersions.set(item.id, item.version);
        merged.push(RemoteAssignmentMapper.toLocal(item, HomeworkStore.instance.getAssignment(item.id)));
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
