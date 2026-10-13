import { http } from '@kit.NetworkKit';
import { ParentIdentity } from '../../domain/model/ParentIdentity';
import { BackendHttpClient } from './BackendHttpClient';

export interface HomeworkCoverageParent {
  parentIdentity: string;
  displayName: string;
  mine: boolean;
  subjects: string[];
  updatedAt: string | null;
}

export interface HomeworkCoverageResponse {
  studentId: string;
  studentName: string;
  taskDate: string;
  parents: HomeworkCoverageParent[];
}

interface HomeworkCoverageUpdateRequest {
  parentIdentity: string;
  subjects: string[];
}

export class HomeworkCoverageRemoteApi {
  static readonly instance: HomeworkCoverageRemoteApi = new HomeworkCoverageRemoteApi();
  private constructor() {}

  async get(
    studentId: string,
    taskDate: string,
    parentIdentity: ParentIdentity
  ): Promise<HomeworkCoverageResponse> {
    let path = `/api/v1/students/${encodeURIComponent(studentId)}/homework-coverage?taskDate=${encodeURIComponent(taskDate)}&parentIdentity=${encodeURIComponent(parentIdentity)}`;
    let response = await BackendHttpClient.instance.requestFor(
      'homework.coverage.get', path, http.RequestMethod.GET);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('今日作业协同状态加载失败');
    }
    return JSON.parse(response.body) as HomeworkCoverageResponse;
  }

  async updateMine(
    studentId: string,
    taskDate: string,
    parentIdentity: ParentIdentity,
    subjects: string[]
  ): Promise<HomeworkCoverageResponse> {
    let path = `/api/v1/students/${encodeURIComponent(studentId)}/homework-coverage/${encodeURIComponent(taskDate)}/me`;
    let payload: HomeworkCoverageUpdateRequest = {
      parentIdentity: parentIdentity,
      subjects: subjects.slice()
    };
    let response = await BackendHttpClient.instance.requestFor(
      'homework.coverage.update', path, http.RequestMethod.PUT, payload);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error('今日作业协同状态保存失败');
    }
    return JSON.parse(response.body) as HomeworkCoverageResponse;
  }
}
