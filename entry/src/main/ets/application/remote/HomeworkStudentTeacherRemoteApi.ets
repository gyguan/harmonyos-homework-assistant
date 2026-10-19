import { http } from '@kit.NetworkKit';
import { BackendHttpClient } from './BackendHttpClient';

export interface HomeworkTeacherOption {
  id: string;
  teacherName: string;
  subject: string;
  enabled: boolean;
}

export class HomeworkStudentTeacherRemoteApi {
  static readonly instance: HomeworkStudentTeacherRemoteApi = new HomeworkStudentTeacherRemoteApi();
  private constructor() {}

  async list(studentId: string): Promise<HomeworkTeacherOption[]> {
    let result = await BackendHttpClient.instance.requestFor(
      'homework.teachers.list',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/teachers`,
      http.RequestMethod.GET);
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw new Error('老师列表加载失败');
    }
    return JSON.parse(result.body) as HomeworkTeacherOption[];
  }

  async register(studentId: string, teacherName: string, subject: string): Promise<HomeworkTeacherOption> {
    let result = await BackendHttpClient.instance.requestFor(
      'homework.teachers.save',
      `/api/v1/students/${encodeURIComponent(studentId)}/homework/teachers`,
      http.RequestMethod.POST, { teacherName: teacherName, subject: subject });
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw new Error('保存老师失败，请检查姓名或网络');
    }
    return JSON.parse(result.body) as HomeworkTeacherOption;
  }
}
