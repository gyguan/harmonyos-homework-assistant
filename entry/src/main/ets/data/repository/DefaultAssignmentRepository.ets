import { BackendSession } from '../../application/remote/BackendSession';
import { AssignmentSyncEntry, HomeworkRemoteApi } from '../../application/remote/HomeworkRemoteApi';
import { RemoteAssignment, RemoteAssignmentMapper } from '../../application/remote/RemoteModels';
import { AssignmentAction } from '../../domain/model/AssignmentAction';
import { AssignmentFilter } from '../../domain/model/AssignmentFilter';
import { AssignmentReviewDecision } from '../../domain/model/AssignmentReviewDecision';
import { Assignment, StudentProfile, TodaySummary } from '../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../domain/port/AssignmentRepository';
import { AssignmentQuery } from '../../domain/service/AssignmentQuery';
import { AssignmentLocalDataSource, DefaultAssignmentLocalDataSource } from '../local/AssignmentLocalDataSource';

export class DefaultAssignmentRepository implements AssignmentRepository {
  static readonly instance: DefaultAssignmentRepository = new DefaultAssignmentRepository();
  private remoteSummary: TodaySummary | null = null;
  private remoteSummaryStudentId: string = '';
  private queryCache: Assignment[] = [];
  private readonly local: AssignmentLocalDataSource = DefaultAssignmentLocalDataSource.instance;
  private syncRunning: boolean = false;
  private syncRequested: boolean = false;

  private constructor() {}

  requestSync(): void {
    if (!BackendSession.instance.isConnected()) return;
    this.syncRequested = true;
    if (!this.syncRunning) void this.flushSync();
  }

  getActiveStudent(): StudentProfile {
    return this.local.getActiveStudent();
  }

  listCached(filter?: AssignmentFilter): Assignment[] {
    let items = this.local.listAssignments();
    if (filter === undefined) return AssignmentQuery.sort(items);
    return AssignmentQuery.filter(items, filter);
  }

  async query(filter: AssignmentFilter): Promise<Assignment[]> {
    if (!BackendSession.instance.isConnected()) {
      this.queryCache = this.listCached(filter);
      return this.queryCache.slice();
    }
    try {
      let studentId = this.local.getActiveStudentId();
      let remoteItems = await HomeworkRemoteApi.instance.listFiltered(studentId, filter);
      let mapped: Assignment[] = [];
      for (let remote of remoteItems) {
        let existing = this.local.getAssignment(remote.id);
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
    return this.local.getAssignment(assignmentId);
  }

  getCachedSummary(): TodaySummary {
    let activeStudentId = this.local.getActiveStudentId();
    if (this.remoteSummary !== null && this.remoteSummaryStudentId === activeStudentId) return this.remoteSummary;
    return this.local.getTodaySummary();
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

    try {
      let remote = await HomeworkRemoteApi.instance.performAction(assignmentId, current.remoteVersion, action);
      let mapped = RemoteAssignmentMapper.toLocal(remote, this.local.getAssignment(assignmentId));
      this.applyAuthoritative(mapped);
      return mapped;
    } catch {
      // START can server-pause another active assignment, and AppShell refresh is asynchronous.
      // Recover a stale local version by fetching only this assignment and retrying the command once.
      let latest = await HomeworkRemoteApi.instance.get(assignmentId);
      let refreshed = RemoteAssignmentMapper.toLocal(latest, this.local.getAssignment(assignmentId));
      this.applyAuthoritative(refreshed);
      if (latest.version === current.remoteVersion) {
        throw new Error('REMOTE_ACTION_FAILED');
      }
      let retried = await HomeworkRemoteApi.instance.performAction(assignmentId, latest.version, action);
      let mapped = RemoteAssignmentMapper.toLocal(retried, this.local.getAssignment(assignmentId));
      this.applyAuthoritative(mapped);
      return mapped;
    }
  }

  async review(assignmentId: string, decision: AssignmentReviewDecision, note: string): Promise<Assignment> {
    let current = this.getCached(assignmentId);
    if (current === null) throw new Error('作业不存在');

    // Keep the same narrow seed/demo compatibility boundary as student execution. A real
    // published Assignment is reviewed only after the server accepts the current version.
    if (current.remoteVersion <= 0 && current.candidateId.length === 0) {
      let completed = decision === AssignmentReviewDecision.APPROVE;
      if (!this.local.reviewAssignment(assignmentId, completed, note)) {
        throw new Error('当前作业状态不能验收');
      }
      let updated = this.local.getAssignment(assignmentId);
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
    let mapped = RemoteAssignmentMapper.toLocal(remote, this.local.getAssignment(assignmentId));
    this.applyAuthoritative(mapped);
    return mapped;
  }

  applyAuthoritative(updated: Assignment): void {
    let assignments = this.local.listAssignments();
    let replaced = false;
    for (let i = 0; i < assignments.length; i++) {
      if (assignments[i].id !== updated.id) continue;
      assignments[i] = updated;
      replaced = true;
      break;
    }
    if (!replaced) assignments.push(updated);
    this.local.replaceAssignmentsForActiveStudent(assignments);
    this.replaceQueryCacheItem(updated);
    // Any authoritative assignment mutation can change nextAssignmentId/progress counters.
    // Drop the remote summary immediately so hidden Home surfaces re-render from the updated
    // local Assignment cache before the asynchronous background sync completes.
    this.remoteSummary = null;
    this.remoteSummaryStudentId = '';
  }

  async refresh(): Promise<boolean> {
    // One authoritative assignment snapshot is enough to rebuild every cached home/progress metric.
    // Submission evidence is deliberately loaded on demand by ParentSubmissionEvidenceService;
    // never fan out one submissions request per assignment during a general refresh.
    this.queryCache = [];
    this.remoteSummary = null;
    this.remoteSummaryStudentId = '';
    if (!BackendSession.instance.isConnected()) return false;
    let synced = await this.syncActiveStudentAssignments();
    if (!synced) return false;

    let activeStudentId = this.local.getActiveStudentId();
    this.remoteSummary = this.local.getTodaySummary();
    this.remoteSummaryStudentId = activeStudentId;
    return true;
  }

  private async syncActiveStudentAssignments(): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    let studentId = this.local.getActiveStudentId();
    try {
      // Fetch the server snapshot exactly once. Mutating commands below already return the
      // authoritative Assignment, so there is no reason to GET the same list a second time.
      let remote = await HomeworkRemoteApi.instance.list(studentId);
      let remoteById: Map<string, RemoteAssignment> = new Map<string, RemoteAssignment>();
      let remoteOrder: string[] = [];
      for (let item of remote) {
        remoteById.set(item.id, item);
        remoteOrder.push(item.id);
      }

      let localAssignments = this.local.listAssignments();
      let dirtyEntries: AssignmentSyncEntry[] = [];
      for (let assignment of localAssignments) {
        let existing = remoteById.get(assignment.id);
        if (existing === undefined) {
          // Only real assignments published from Candidate drafts are uploaded automatically.
          // Demo/seed assignments remain local fixtures.
          if (assignment.candidateId.length === 0) continue;
          let created = await HomeworkRemoteApi.instance.create(assignment);
          remoteById.set(created.id, created);
          remoteOrder.push(created.id);
          continue;
        }

        // Dirty updates are collected first and sent in bounded batches below. A version mismatch
        // deliberately keeps the already fetched authoritative server snapshot.
        if (assignment.syncDirty && assignment.remoteVersion === existing.version) {
          dirtyEntries.push({ assignment: assignment, version: assignment.remoteVersion });
        }
      }

      for (let offset = 0; offset < dirtyEntries.length; offset += 50) {
        let chunk = dirtyEntries.slice(offset, Math.min(offset + 50, dirtyEntries.length));
        try {
          let batch = await HomeworkRemoteApi.instance.sync(studentId, chunk);
          for (let result of batch.results) {
            remoteById.set(result.assignment.id, result.assignment);
          }
        } catch {
          // Keep the original server snapshot when a transient batch sync fails.
        }
      }

      let merged: Assignment[] = [];
      for (let assignmentId of remoteOrder) {
        let item = remoteById.get(assignmentId);
        if (item === undefined) continue;
        merged.push(RemoteAssignmentMapper.toLocal(item, this.local.getAssignment(item.id)));
      }
      this.local.replaceAssignmentsForActiveStudent(merged);
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
    if (action === AssignmentAction.START) changed = this.local.startAssignment(assignmentId);
    else if (action === AssignmentAction.PAUSE) changed = this.local.pauseAssignment(assignmentId);
    else if (action === AssignmentAction.READY_TO_SUBMIT) changed = this.local.markReadyToSubmit(assignmentId);
    if (!changed) throw new Error('当前作业状态不能执行这个动作');
    let updated = this.local.getAssignment(assignmentId);
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
