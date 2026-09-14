import { http } from '@kit.NetworkKit';
import { Assignment } from '../../domain/model/HomeworkModels';
import { BackendHttpClient } from './BackendHttpClient';
import { RemoteAssignment } from './RemoteModels';

interface CreateAssignmentBody {
  id: string; subject: string; title: string; instruction: string; textbookRef: string; dueText: string;
  status: string; sourceLabel: string; sourceExcerpt: string;
}
interface UpdateAssignmentBody {
  version: number; subject: string; title: string; instruction: string; textbookRef: string; dueText: string;
  status: string; sourceLabel: string; sourceExcerpt: string;
}

export class HomeworkRemoteApi {
  static readonly instance: HomeworkRemoteApi = new HomeworkRemoteApi();
  private constructor() {}

  async list(studentId: string): Promise<RemoteAssignment[]> {
    let response = await BackendHttpClient.instance.request(`/api/v1/students/${encodeURIComponent(studentId)}/assignments`, http.RequestMethod.GET);
    if (response.statusCode !== 200) throw new Error(`拉取作业失败: ${response.statusCode}`);
    return JSON.parse(response.body) as RemoteAssignment[];
  }

  async create(assignment: Assignment): Promise<RemoteAssignment> {
    let body: CreateAssignmentBody = this.createBody(assignment);
    let response = await BackendHttpClient.instance.request(`/api/v1/students/${encodeURIComponent(assignment.studentId)}/assignments`, http.RequestMethod.POST, body);
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`上传作业失败: ${response.statusCode}`);
    return JSON.parse(response.body) as RemoteAssignment;
  }

  async update(assignment: Assignment, version: number): Promise<RemoteAssignment> {
    let body: UpdateAssignmentBody = {
      version: version, subject: assignment.subject, title: assignment.title, instruction: assignment.instruction,
      textbookRef: assignment.textbookRef, dueText: assignment.dueText, status: assignment.status,
      sourceLabel: '', sourceExcerpt: ''
    };
    let response = await BackendHttpClient.instance.request(`/api/v1/assignments/${encodeURIComponent(assignment.id)}`, http.RequestMethod.PATCH, body);
    if (response.statusCode === 409) throw new Error('REMOTE_CONFLICT');
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error(`更新作业失败: ${response.statusCode}`);
    return JSON.parse(response.body) as RemoteAssignment;
  }

  private createBody(assignment: Assignment): CreateAssignmentBody {
    return { id: assignment.id, subject: assignment.subject, title: assignment.title, instruction: assignment.instruction,
      textbookRef: assignment.textbookRef, dueText: assignment.dueText, status: assignment.status, sourceLabel: '', sourceExcerpt: '' };
  }
}
