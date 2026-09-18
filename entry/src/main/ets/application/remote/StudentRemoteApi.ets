import { http } from '@kit.NetworkKit';
import { StudentProfile } from '../../domain/model/HomeworkModels';
import { BackendHttpClient } from './BackendHttpClient';

export interface RemoteStudent {
  id: string;
  name: string;
  grade: string;
  className: string;
  semester: string;
  textbookSummary: string;
}

export class StudentRemoteApi {
  static readonly instance: StudentRemoteApi = new StudentRemoteApi();
  private constructor() {}

  async list(): Promise<RemoteStudent[]> {
    let response = await BackendHttpClient.instance.requestFor(
      'family.students.list', '/api/v1/students', http.RequestMethod.GET);
    if (response.statusCode !== 200) throw new Error('读取家庭成员失败');
    return JSON.parse(response.body) as RemoteStudent[];
  }

  async save(student: StudentProfile): Promise<RemoteStudent> {
    let response = await BackendHttpClient.instance.requestFor(
      'family.student.save', '/api/v1/students', http.RequestMethod.PUT, student);
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error('保存孩子资料失败');
    return JSON.parse(response.body) as RemoteStudent;
  }

  async delete(studentId: string): Promise<void> {
    let response = await BackendHttpClient.instance.requestFor(
      'family.student.delete',
      `/api/v1/students/${encodeURIComponent(studentId)}`, http.RequestMethod.DELETE);
    if (response.statusCode === 409) throw new Error('该孩子已有作业或是家庭最后一个孩子，暂不能删除');
    if (response.statusCode < 200 || response.statusCode >= 300) throw new Error('删除孩子失败');
  }
}
