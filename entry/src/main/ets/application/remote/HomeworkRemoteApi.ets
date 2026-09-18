import { http } from '@kit.NetworkKit';
import { AssignmentAction } from '../../domain/model/AssignmentAction';
import { AssignmentFilter, AssignmentTypeFilter } from '../../domain/model/AssignmentFilter';
import { AssignmentReviewDecision } from '../../domain/model/AssignmentReviewDecision';
import { Assignment, TodaySummary } from '../../domain/model/HomeworkModels';
import { BackendHttpClient } from './BackendHttpClient';
import { RemoteAssignment } from './RemoteModels';

interface CreateAssignmentBody {
  id: string; subject: string; title: string; instruction: string; textbookRef: string; dueText: string;
  assignmentType: string; subjectCode: string; dueAtEpochMs: number; dueTimezone: string;
  status: string; sourceLabel: string; sourceExcerpt: string; expectedMinutes: number;
  startedAtEpochMs: number; finishedAtEpochMs: number; elapsedSeconds: number; reviewNote: string;
}
interface UpdateAssignmentBody {
  version: number; subject: string; title: string; instruction: string; textbookRef: string; dueText: string;
  assignmentType: string; subjectCode: string; dueAtEpochMs: number; dueTimezone: string;
  status: string; sourceLabel: string; sourceExcerpt: string; expectedMinutes: number;
  startedAtEpochMs: number; finishedAtEpochMs: number; elapsedSeconds: number; reviewNote: string;
}
interface AssignmentActionBody {
  action: string;
  version: number;
}
interface AssignmentReviewBody {
  decision: string;
  version: number;
  note: string;
}
interface BatchPublishItemBody {
  candidateId: string;
  assignment: CreateAssignmentBody;
}
interface BatchPublishBody {
  items: BatchPublishItemBody[];
}
interface RemoteAssignmentPage {
  items: RemoteAssignment[];
  page: number;
  limit: number;
  hasMore: boolean;
  total: number;
}
interface BatchSyncItemBody {
  id: string;
  assignment: UpdateAssignmentBody;
}
interface BatchSyncBody {
  items: BatchSyncItemBody[];
}
export interface AssignmentSyncEntry {
  assignment: Assignment;
  version: number;
}
export interface RemoteBatchSyncResult {
  id: string;
  applied: boolean;
  assignment: RemoteAssignment;
}
export interface RemoteBatchSyncResponse {
  processedCount: number;
  results: RemoteBatchSyncResult[];
}

export interface BatchPublishEntry {
  candidateId: string;
  assignment: Assignment;
}

export interface RemoteBatchPublishResult {
  candidateId: string;
  assignment: RemoteAssignment;
}

export interface RemoteBatchPublishResponse {
  atomic: boolean;
  publishedCount: number;
  results: RemoteBatchPublishResult[];
}

export class HomeworkRemoteApi {
  static readonly instance: HomeworkRemoteApi = new HomeworkRemoteApi();
  private constructor() {}

  async list(studentId: string): Promise<RemoteAssignment[]> {
    return this.listPaged(studentId, [], 'assignment.sync.snapshot');
  }

  async listFiltered(studentId: string, filter: AssignmentFilter): Promise<RemoteAssignment[]> {
    let params: string[] = [];
    if (filter.assignmentType !== AssignmentTypeFilter.ALL) {
      params.push(`type=${encodeURIComponent(filter.assignmentType)}`);
    }
    if (filter.subjectCode !== 'ALL') {
      params.push(`subjectCode=${encodeURIComponent(filter.subjectCode)}`);
    }
    if (filter.fromEpochMs > 0) params.push(`from=${filter.fromEpochMs}`);
    if (filter.toEpochMs > 0) params.push(`to=${filter.toEpochMs}`);
    if (filter.undatedOnly) params.push('undated=true');
    if (filter.statuses.length === 1) params.push(`status=${encodeURIComponent(filter.statuses[0])}`);

    return this.listPaged(studentId, params, 'assignment.query');
  }

  async todaySummary(studentId: string): Promise<TodaySummary> {
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.summary',
      `/api/v1/students/${encodeURIComponent(studentId)}/assignments/summary`, http.RequestMethod.GET);
    if (response.statusCode !== 200) throw new Error(`拉取今日作业摘要失败: ${response.statusCode}`);
    return JSON.parse(response.body) as TodaySummary;
  }

  async create(assignment: Assignment): Promise<RemoteAssignment> {
    let body: CreateAssignmentBody = this.createBody(assignment);
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.create',
      `/api/v1/students/${encodeURIComponent(assignment.studentId)}/assignments`,
      http.RequestMethod.POST, body);
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`上传作业失败: ${response.statusCode}`);
    return JSON.parse(response.body) as RemoteAssignment;
  }

  async batchPublish(studentId: string, entries: BatchPublishEntry[]): Promise<RemoteBatchPublishResponse> {
    let items: BatchPublishItemBody[] = [];
    for (let entry of entries) {
      items.push({ candidateId: entry.candidateId, assignment: this.createBody(entry.assignment) });
    }
    let body: BatchPublishBody = { items: items };
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.batchPublish',
      `/api/v1/students/${encodeURIComponent(studentId)}/assignments/batch`, http.RequestMethod.POST, body);
    if (response.statusCode === 409) throw new Error('BATCH_PUBLISH_CONFLICT');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`批量发布失败: ${response.statusCode}`);
    }
    return JSON.parse(response.body) as RemoteBatchPublishResponse;
  }

  async performAction(assignmentId: string, version: number, action: AssignmentAction): Promise<RemoteAssignment> {
    let body: AssignmentActionBody = { action: action, version: version };
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.action',
      `/api/v1/assignments/${encodeURIComponent(assignmentId)}/actions`, http.RequestMethod.POST, body);
    if (response.statusCode === 409) throw new Error('REMOTE_CONFLICT');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`执行作业动作失败: ${response.statusCode}`);
    }
    return JSON.parse(response.body) as RemoteAssignment;
  }

  async review(assignmentId: string, version: number, decision: AssignmentReviewDecision, note: string): Promise<RemoteAssignment> {
    let body: AssignmentReviewBody = { decision: decision, version: version, note: note };
    let response = await BackendHttpClient.instance.requestFor(
      'parent.review',
      `/api/v1/assignments/${encodeURIComponent(assignmentId)}/review`, http.RequestMethod.POST, body);
    if (response.statusCode === 409) throw new Error('REMOTE_CONFLICT');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`验收作业失败: ${response.statusCode}`);
    }
    return JSON.parse(response.body) as RemoteAssignment;
  }

  async update(assignment: Assignment, version: number): Promise<RemoteAssignment> {
    let body: UpdateAssignmentBody = this.updateBody(assignment, version);
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.update',
      `/api/v1/assignments/${encodeURIComponent(assignment.id)}`, http.RequestMethod.PUT, body);
    if (response.statusCode === 409) throw new Error('REMOTE_CONFLICT');
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`更新作业失败: ${response.statusCode}`);
    return JSON.parse(response.body) as RemoteAssignment;
  }

  async sync(studentId: string, entries: AssignmentSyncEntry[]): Promise<RemoteBatchSyncResponse> {
    let items: BatchSyncItemBody[] = [];
    for (let entry of entries) {
      items.push({ id: entry.assignment.id, assignment: this.updateBody(entry.assignment, entry.version) });
    }
    let body: BatchSyncBody = { items: items };
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.sync.dirty',
      `/api/v1/students/${encodeURIComponent(studentId)}/assignments/sync`,
      http.RequestMethod.POST, body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`批量同步作业失败: ${response.statusCode}`);
    }
    return JSON.parse(response.body) as RemoteBatchSyncResponse;
  }

  async delete(assignmentId: string): Promise<boolean> {
    let response = await BackendHttpClient.instance.requestFor(
      'assignment.delete',
      `/api/v1/assignments/${encodeURIComponent(assignmentId)}`, http.RequestMethod.DELETE);
    return response.statusCode === 200 || response.statusCode === 204 || response.statusCode === 404;
  }

  private async listPaged(studentId: string, baseParams: string[], scene: string): Promise<RemoteAssignment[]> {
    let all: RemoteAssignment[] = [];
    let page: number = 0;
    while (page < 100) {
      let params = baseParams.slice();
      params.push(`page=${page}`);
      params.push('limit=100');
      let response = await BackendHttpClient.instance.requestFor(
        scene,
        `/api/v1/students/${encodeURIComponent(studentId)}/assignments/page?${params.join('&')}`,
        http.RequestMethod.GET);
      if (response.statusCode !== 200) throw new Error(`拉取作业失败: ${response.statusCode}`);
      let result = JSON.parse(response.body) as RemoteAssignmentPage;
      for (let item of result.items) all.push(item);
      if (!result.hasMore) return all;
      page++;
    }
    throw new Error('作业分页超过安全上限');
  }

  private updateBody(assignment: Assignment, version: number): UpdateAssignmentBody {
    return {
      version: version, subject: assignment.subject, title: assignment.title, instruction: assignment.instruction,
      textbookRef: assignment.textbookRef, dueText: assignment.dueText,
      assignmentType: assignment.assignmentType, subjectCode: assignment.subjectCode,
      dueAtEpochMs: assignment.dueAtEpochMs, dueTimezone: assignment.dueTimezone,
      status: assignment.status, sourceLabel: '', sourceExcerpt: '', expectedMinutes: assignment.expectedMinutes,
      startedAtEpochMs: assignment.startedAtEpochMs, finishedAtEpochMs: assignment.finishedAtEpochMs,
      elapsedSeconds: assignment.elapsedSeconds, reviewNote: assignment.reviewNote
    };
  }

  private createBody(assignment: Assignment): CreateAssignmentBody {
    return { id: assignment.id, subject: assignment.subject, title: assignment.title, instruction: assignment.instruction,
      textbookRef: assignment.textbookRef, dueText: assignment.dueText,
      assignmentType: assignment.assignmentType, subjectCode: assignment.subjectCode,
      dueAtEpochMs: assignment.dueAtEpochMs, dueTimezone: assignment.dueTimezone,
      status: assignment.status, sourceLabel: assignment.candidateId.length > 0 ? '家长确认发布' : '',
      sourceExcerpt: '', expectedMinutes: assignment.expectedMinutes,
      startedAtEpochMs: assignment.startedAtEpochMs, finishedAtEpochMs: assignment.finishedAtEpochMs,
      elapsedSeconds: assignment.elapsedSeconds, reviewNote: assignment.reviewNote };
  }
}
