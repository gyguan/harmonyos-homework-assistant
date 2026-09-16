import { HomeworkSyncService } from '../../application/remote/HomeworkSyncService';
import { BackendSession } from '../../application/remote/BackendSession';
import { HomeworkRemoteApi } from '../../application/remote/HomeworkRemoteApi';
import { RemoteAssignmentMapper } from '../../application/remote/RemoteModels';
import { HomeworkStore } from '../HomeworkStore';
import { AssignmentAction } from '../../domain/model/AssignmentAction';
import { AssignmentFilter } from '../../domain/model/AssignmentFilter';
import { Assignment, StudentProfile, TodaySummary } from '../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../domain/port/AssignmentRepository';
import { AssignmentQuery } from '../../domain/service/AssignmentQuery';

export class DefaultAssignmentRepository implements AssignmentRepository {
  static readonly instance: DefaultAssignmentRepository = new DefaultAssignmentRepository();
  private remoteSummary: TodaySummary | null = null;
  private queryCache: Assignment[] = [];

  private constructor() {}

  getActiveStudent(): StudentProfile {
    return HomeworkStore.instance.getStudent();
  }

  listCached(filter?: AssignmentFilter): Assignment[] {
    let items = HomeworkStore.instance.getAssignments().slice();
    if (filter === undefined) return AssignmentQuery.sort(items);
    return AssignmentQuery.filter(items, filter);
  }

  async query(filter: AssignmentFilter): Promise<Assignment[]> {
    if (!BackendSession.instance.isConnected()) {
      this.queryCache = this.listCached(filter);
      return this.queryCache.slice();
    }
    try {
      let studentId = HomeworkStore.instance.getActiveStudentId();
      let remoteItems = await HomeworkRemoteApi.instance.listFiltered(studentId, filter);
      let mapped: Assignment[] = [];
      for (let remote of remoteItems) {
        let existing = HomeworkStore.instance.getAssignment(remote.id);
        mapped.push(RemoteAssignmentMapper.toLocal(remote, existing));
      }
      this.queryCache = mapped;
      return mapped.slice();
    } catch {
      this.queryCache = this.listCached(filter);
      return this.queryCache.slice();
    }
  }

  getCached(assignmentId: string): Assignment | null {
    for (let item of this.queryCache) if (item.id === assignmentId) return item;
    return HomeworkStore.instance.getAssignment(assignmentId);
  }

  getCachedSummary(): TodaySummary {
    if (this.remoteSummary !== null) return this.remoteSummary;
    return HomeworkStore.instance.getTodaySummary();
  }

  async performAction(assignmentId: string, action: AssignmentAction): Promise<Assignment> {
    let current = this.getCached(assignmentId);
    if (current === null) throw new Error('作业不存在');

    // Seed/demo assignments intentionally remain local. Published assignments must use the
    // server command path so status and timing cannot be overwritten by a client clock.
    if (current.remoteVersion <= 0 && current.candidateId.length === 0) {
      return this.performLocalDemoAction(assignmentId, action);
    }
    if (!BackendSession.instance.isConnected()) {
      throw new Error('当前离线，只能查看已缓存作业；联网后才能更新作业状态');
    }
    if (current.remoteVersion <= 0) {
      throw new Error('作业尚未完成云端同步，请刷新后重试');
    }

    let remote = await HomeworkRemoteApi.instance.performAction(assignmentId, current.remoteVersion, action);
    let mapped = RemoteAssignmentMapper.toLocal(remote, HomeworkStore.instance.getAssignment(assignmentId));
    this.applyAuthoritative(mapped);
    return mapped;
  }

  applyAuthoritative(updated: Assignment): void {
    let assignments = HomeworkStore.instance.getAssignments().slice();
    let replaced = false;
    for (let i = 0; i < assignments.length; i++) {
      if (assignments[i].id !== updated.id) continue;
      assignments[i] = updated;
      replaced = true;
      break;
    }
    if (!replaced) assignments.push(updated);
    HomeworkStore.instance.replaceAssignmentsForActiveStudent(assignments);
    this.replaceQueryCacheItem(updated);
    // Any authoritative assignment mutation can change nextAssignmentId/progress counters.
    // Drop the remote summary immediately so hidden Home surfaces re-render from the updated
    // local Assignment cache before the asynchronous background sync completes.
    this.remoteSummary = null;
  }

  async refresh(): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    let synced = await HomeworkSyncService.instance.syncActiveStudent();
    if (!synced) return false;
    this.queryCache = [];
    try {
      this.remoteSummary = await HomeworkRemoteApi.instance.todaySummary(HomeworkStore.instance.getActiveStudentId());
    } catch {
      this.remoteSummary = null;
    }
    return true;
  }

  private performLocalDemoAction(assignmentId: string, action: AssignmentAction): Assignment {
    let changed = false;
    if (action === AssignmentAction.START) changed = HomeworkStore.instance.startAssignment(assignmentId);
    else if (action === AssignmentAction.PAUSE) changed = HomeworkStore.instance.pauseAssignment(assignmentId);
    else if (action === AssignmentAction.READY_TO_SUBMIT) changed = HomeworkStore.instance.markReadyToSubmit(assignmentId);
    if (!changed) throw new Error('当前作业状态不能执行这个动作');
    let updated = HomeworkStore.instance.getAssignment(assignmentId);
    if (updated === null) throw new Error('作业不存在');
    this.replaceQueryCacheItem(updated);
    this.remoteSummary = null;
    return updated;
  }

  private replaceQueryCacheItem(updated: Assignment): void {
    for (let i = 0; i < this.queryCache.length; i++) {
      if (this.queryCache[i].id !== updated.id) continue;
      this.queryCache[i] = updated;
      return;
    }
  }
}
