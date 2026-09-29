import { http } from '@kit.NetworkKit';
import {
  ScheduledAssignmentPlan,
  ScheduledAssignmentPlanDraft,
  ScheduledAssignmentRun,
  ScheduledAssignmentTemplate
} from '../../domain/model/ScheduledAssignmentModels';
import { BackendHttpClient } from './BackendHttpClient';

interface RemoteScheduledTemplate {
  assignmentType: string;
  subject: string;
  subjectCode: string;
  title: string;
  instruction: string;
  expectedMinutes: number;
  duePolicy: string;
  dueTime: string;
  dueOffsetMinutes: number;
}

interface RemoteScheduledPlan {
  id: string;
  studentId: string;
  planType: string;
  name: string;
  scheduleType: string;
  timeOfDay: string;
  weekdays: string[];
  startDate: string;
  endDate: string;
  timezone: string;
  status: string;
  nextFireAtEpochMs: number;
  lastFireAtEpochMs: number;
  template: RemoteScheduledTemplate | null;
  version: number;
}

interface RemoteScheduledRun {
  id: string;
  scheduledFireAtEpochMs: number;
  triggerSource: string;
  status: string;
  assignmentId: string;
  skipReason: string;
  errorMessage: string;
  retryCount: number;
  finishedAtEpochMs: number;
}

interface ScheduledActionBody {
  action: string;
  version: number;
}

interface ScheduledUpdateBody {
  version: number;
  planType: string;
  name: string;
  scheduleType: string;
  timeOfDay: string;
  weekdays: string[];
  startDate: string;
  endDate: string;
  template: ScheduledAssignmentTemplate | null;
}

export class ScheduledAssignmentRemoteApi {
  static readonly instance: ScheduledAssignmentRemoteApi = new ScheduledAssignmentRemoteApi();
  private constructor() {}

  async list(studentId: string): Promise<ScheduledAssignmentPlan[]> {
    let path = '/api/v1/scheduled-assignment-plans?studentId=' + encodeURIComponent(studentId);
    let response = await BackendHttpClient.instance.requestFor(
      'scheduled.assignment.list', path, http.RequestMethod.GET);
    this.requireSuccess(response.statusCode, '读取定时作业失败');
    let items = JSON.parse(response.body) as RemoteScheduledPlan[];
    let result: ScheduledAssignmentPlan[] = [];
    for (let item of items) result.push(this.toPlan(item));
    return result;
  }

  async create(studentId: string, draft: ScheduledAssignmentPlanDraft): Promise<ScheduledAssignmentPlan> {
    let path = '/api/v1/students/' + encodeURIComponent(studentId) + '/scheduled-assignment-plans';
    let response = await BackendHttpClient.instance.requestFor(
      'scheduled.assignment.create', path, http.RequestMethod.POST, draft);
    this.requireSuccess(response.statusCode, '创建定时作业失败');
    return this.toPlan(JSON.parse(response.body) as RemoteScheduledPlan);
  }

  async update(planId: string, version: number,
    draft: ScheduledAssignmentPlanDraft): Promise<ScheduledAssignmentPlan> {
    let body: ScheduledUpdateBody = {
      version: version,
      planType: draft.planType,
      name: draft.name,
      scheduleType: draft.scheduleType,
      timeOfDay: draft.timeOfDay,
      weekdays: draft.weekdays,
      startDate: draft.startDate,
      endDate: draft.endDate,
      template: draft.template
    };
    let path = '/api/v1/scheduled-assignment-plans/' + encodeURIComponent(planId);
    let response = await BackendHttpClient.instance.requestFor(
      'scheduled.assignment.update', path, http.RequestMethod.PUT, body);
    if (response.statusCode === 409) throw new Error('计划已在其他设备更新，请刷新后重试');
    this.requireSuccess(response.statusCode, '更新定时作业失败');
    return this.toPlan(JSON.parse(response.body) as RemoteScheduledPlan);
  }

  async setEnabled(planId: string, version: number, enabled: boolean): Promise<ScheduledAssignmentPlan> {
    let body: ScheduledActionBody = { action: enabled ? 'ENABLE' : 'PAUSE', version: version };
    let path = '/api/v1/scheduled-assignment-plans/' + encodeURIComponent(planId) + '/actions';
    let response = await BackendHttpClient.instance.requestFor(
      'scheduled.assignment.action', path, http.RequestMethod.POST, body);
    if (response.statusCode === 409) throw new Error('计划已在其他设备更新，请刷新后重试');
    this.requireSuccess(response.statusCode, '更新计划状态失败');
    return this.toPlan(JSON.parse(response.body) as RemoteScheduledPlan);
  }

  async delete(planId: string): Promise<void> {
    let path = '/api/v1/scheduled-assignment-plans/' + encodeURIComponent(planId);
    let response = await BackendHttpClient.instance.requestFor(
      'scheduled.assignment.delete', path, http.RequestMethod.DELETE);
    if (response.statusCode !== 204 && response.statusCode !== 200) {
      this.requireSuccess(response.statusCode, '删除定时作业失败');
    }
  }

  async runs(planId: string): Promise<ScheduledAssignmentRun[]> {
    let path = '/api/v1/scheduled-assignment-plans/' + encodeURIComponent(planId) + '/runs';
    let response = await BackendHttpClient.instance.requestFor(
      'scheduled.assignment.runs', path, http.RequestMethod.GET);
    this.requireSuccess(response.statusCode, '读取执行记录失败');
    let items = JSON.parse(response.body) as RemoteScheduledRun[];
    let result: ScheduledAssignmentRun[] = [];
    for (let item of items) {
      result.push({
        id: item.id,
        scheduledFireAtEpochMs: item.scheduledFireAtEpochMs,
        triggerSource: item.triggerSource,
        status: item.status,
        assignmentId: item.assignmentId,
        skipReason: item.skipReason,
        errorMessage: item.errorMessage,
        retryCount: item.retryCount,
        finishedAtEpochMs: item.finishedAtEpochMs
      });
    }
    return result;
  }

  private toPlan(item: RemoteScheduledPlan): ScheduledAssignmentPlan {
    let template: ScheduledAssignmentTemplate | null = null;
    if (item.template !== null) {
      template = {
        assignmentType: item.template.assignmentType,
        subject: item.template.subject,
        subjectCode: item.template.subjectCode,
        title: item.template.title,
        instruction: item.template.instruction,
        expectedMinutes: item.template.expectedMinutes,
        duePolicy: item.template.duePolicy,
        dueTime: item.template.dueTime,
        dueOffsetMinutes: item.template.dueOffsetMinutes
      };
    }
    return {
      id: item.id,
      studentId: item.studentId,
      planType: item.planType,
      name: item.name,
      scheduleType: item.scheduleType,
      timeOfDay: item.timeOfDay,
      weekdays: item.weekdays,
      startDate: item.startDate,
      endDate: item.endDate,
      timezone: item.timezone,
      status: item.status,
      nextFireAtEpochMs: item.nextFireAtEpochMs,
      lastFireAtEpochMs: item.lastFireAtEpochMs,
      template: template,
      version: item.version
    };
  }

  private requireSuccess(statusCode: number, message: string): void {
    if (statusCode < 200 || statusCode >= 300) throw new Error(message + ': ' + statusCode);
  }
}
