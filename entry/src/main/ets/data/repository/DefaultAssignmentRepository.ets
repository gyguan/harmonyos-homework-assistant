import { BackendSession } from '../../application/remote/BackendSession';
import { HomeworkRemoteApi } from '../../application/remote/HomeworkRemoteApi';
import { RemoteAssignment, RemoteAssignmentMapper } from '../../application/remote/RemoteModels';
import { RemoteSubmissionApi } from '../../application/remote/RemoteSubmissionApi';
import { RemoteSubmissionCache } from '../../application/remote/RemoteSubmissionCache';
import { HomeworkStore } from '../HomeworkStore';
import { AssignmentAction } from '../../domain/model/AssignmentAction';
import { AssignmentFilter } from '../../domain/model/AssignmentFilter';
import { AssignmentReviewDecision } from '../../domain/model/AssignmentReviewDecision';
import { Assignment, StudentProfile, TodaySummary } from '../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../domain/port/AssignmentRepository';
import { AssignmentQuery } from '../../domain/service/AssignmentQuery';

export class DefaultAssignmentRepository implements AssignmentRepository {
  static readonly instance: DefaultAssignmentRepository = new DefaultAssignmentRepository();
  private remoteSummary: TodaySummary | null = null;
  private remoteSummaryStudentId: string = '';
  private queryCache: Assignment[] = [];
  private syncRunning: boolean = false;
  private syncRequested: boolean = false;

  private constructor() {}

  requestSync(): void {
    if (!BackendSession.instance.isConnected()) return;
    this.syncRequested = true;
    if (!this.syncRunning) void this.flushSync();
  }

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
      // The backend query can intentionally receive only filters it supports efficiently
      // (for example a single status). Always apply the complete V2 filter locally too so
      // multi-status views such as Parent "需关注" have exact semantics.
      this.queryCache = AssignmentQuery.filter(mapped, filter);
      return this.queryCache.slice();
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
    let activeStudentId = HomeworkStore.instance.getActiveStudentId();
    if (this.remoteSummary !== null && this.remoteSummaryStudentId === activeStudentId) return this.remoteSummary;
    return HomeworkStore.instance.getTodaySummary();
  }

  async create(assignment: Assignment): Promise<Assignment> {
    if (!BackendSession.instance.isConnected()) {
      throw new Error('当前离线，连接家庭云端后才能布置任务');
    }
    let activeStudent = this.getActiveStudent();
    if (assignment.studentId !== activeStudent.id) {
      throw new Error('任务不属于当前孩子');
    }

    let remote = await HomeworkRemoteApi.instance.create(assignment);
    let mapped = RemoteAssignmentMapper.toLocal(remote, assignment);
    this.applyAuthoritative(mapped);
    return mapped;
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

  async review(assignmentId: string, decision: AssignmentReviewDecision, note: string): Promise<Assignment> {
    let current = this.getCached(assignmentId);
    if (current === null) throw new Error('作业不存在');

    // Keep the same narrow seed/demo compatibility boundary as student execution. A real
    // published Assignment is reviewed only after the server accepts the current version.
    if (current.remoteVersion <= 0 && current.candidateId.length === 0) {
      let completed = decision === AssignmentReviewDecision.APPROVE;
      if (!HomeworkStore.instance.reviewAssignment(assignmentId, completed, note)) {
        throw new Error('当前作业状态不能验收');
      }
      let updated = HomeworkStore.instance.getAssignment(assignmentId);
      if (updated === null) throw new Error('作业不存在');
      this.replaceQueryCacheItem(updated);
      this.remoteSummary = null;
      this.remoteSummaryStudentId = '';
      return updated;
    }
    if (!BackendSession.instance.isConnected()) {
      throw new Error('当前离线，只能查看已缓存提交；联网后才能验收作业');
    }
    if (current.remoteVersion <= 0) {
      throw new Error('作业尚未完成云端同步，请刷新后重试');
    }

    let remote = await HomeworkRemoteApi.instance.review(
      assignmentId, current.remoteVersion, decision, note.trim());
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
    this.remoteSummaryStudentId = '';
  }

  async refresh(): Promise<boolean> {
    // A refresh always starts a new active-child context. Clear in-memory query/summary caches
    // synchronously so the newly selected child can never render a sibling's cached summary.
    this.queryCache = [];
    this.remoteSummary = null;
    this.remoteSummaryStudentId = '';
    if (!BackendSession.instance.isConnected()) return false;
    let synced = await this.syncActiveStudentAssignments();
    if (!synced) return false;
    let activeStudentId = HomeworkStore.instance.getActiveStudentId();
    try {
      this.remoteSummary = await HomeworkRemoteApi.instance.todaySummary(activeStudentId);
      this.remoteSummaryStudentId = activeStudentId;
    } catch {
      this.remoteSummary = null;
      this.remoteSummaryStudentId = '';
    }
    return true;
  }

  private async syncActiveStudentAssignments(): Promise<boolean> {
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
          // Only real assignments published from Candidate drafts are uploaded automatically.
          // Demo/seed assignments remain local fixtures.
          if (assignment.candidateId.length === 0) continue;
          await HomeworkRemoteApi.instance.create(assignment);
          continue;
        }

        // A client may update only from the exact server version it last persisted. If another
        // device advanced the version, the authoritative refresh below deliberately wins.
        if (assignment.syncDirty && assignment.remoteVersion === existing.version) {
          try {
            await HomeworkRemoteApi.instance.update(assignment, assignment.remoteVersion);
          } catch {
            // Conflict/transient failures are reconciled by the authoritative final refresh.
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
          // Submission metadata is best-effort and must not block Assignment reconciliation.
        }
      }
      HomeworkStore.instance.replaceAssignmentsForActiveStudent(merged);
      return true;
    } catch {
      return false;
    }
  }

  private async flushSync(): Promise<void> {
    this.syncRunning = true;
    while (this.syncRequested) {
      this.syncRequested = false;
      await this.refresh();
    }
    this.syncRunning = false;
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
    this.remoteSummaryStudentId = '';
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
