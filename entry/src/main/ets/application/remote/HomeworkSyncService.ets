import { HomeworkStore } from '../../data/HomeworkStore';
import { Assignment } from '../../domain/model/HomeworkModels';
import { BackendSession } from './BackendSession';
import { HomeworkRemoteApi } from './HomeworkRemoteApi';
import { RemoteAssignment, RemoteAssignmentMapper } from './RemoteModels';

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
          await HomeworkRemoteApi.instance.create(assignment);
        } else {
          try { await HomeworkRemoteApi.instance.update(assignment, existing.version); } catch {}
        }
      }
      let finalRemote = await HomeworkRemoteApi.instance.list(studentId);
      let merged: Assignment[] = [];
      for (let item of finalRemote) merged.push(RemoteAssignmentMapper.toLocal(item, HomeworkStore.instance.getAssignment(item.id)));
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
