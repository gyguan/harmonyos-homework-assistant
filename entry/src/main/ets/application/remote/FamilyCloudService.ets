import { DefaultFamilyContextRepository } from '../../data/repository/DefaultFamilyContextRepository';
import { StudentProfile } from '../../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../../domain/port/FamilyContextRepository';
import { ParentAccessState } from '../../domain/service/ParentAccessState';
import { BackendSession } from './BackendSession';
import { ParentAccessRemoteApi } from './ParentAccessRemoteApi';
import { RemoteStudent, StudentRemoteApi } from './StudentRemoteApi';

export class FamilyCloudService {
  static readonly instance: FamilyCloudService = new FamilyCloudService();
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  private constructor() {}

  async syncParentAccess(): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    try {
      let localValue = this.familyContext.getSettings().parentAccessCode;
      let status = await ParentAccessRemoteApi.instance.status();

      if (!status.enabled && ParentAccessState.isLegacyCode(localValue)) {
        status = await ParentAccessRemoteApi.instance.setCode(localValue);
      }

      this.familyContext.updateParentAccessCode(
        status.enabled ? ParentAccessState.CLOUD_ENABLED : '');
      return true;
    } catch {
      return false;
    }
  }

  async syncStudents(): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    try {
      let remote = await StudentRemoteApi.instance.list();
      if (remote.length === 0) return false;
      this.apply(remote);
      return true;
    } catch {
      return false;
    }
  }

  async saveStudent(student: StudentProfile): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    try {
      await StudentRemoteApi.instance.save(student);
      let synced = await this.syncStudents();
      if (synced) this.familyContext.setActiveStudent(student.id);
      return synced;
    } catch {
      return false;
    }
  }

  async deleteStudent(studentId: string): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    try {
      await StudentRemoteApi.instance.delete(studentId);
      return await this.syncStudents();
    } catch {
      return false;
    }
  }

  private apply(remote: RemoteStudent[]): void {
    let students: StudentProfile[] = [];
    for (let item of remote) {
      students.push({
        id: item.id,
        name: item.name,
        grade: item.grade,
        className: item.className,
        semester: item.semester,
        chineseTextbook: item.chineseTextbook,
        mathTextbook: item.mathTextbook,
        englishTextbook: item.englishTextbook,
        otherTextbooks: item.otherTextbooks,
        textbookSummary: item.textbookSummary
      });
    }
    this.familyContext.replaceStudents(students);
  }
}
