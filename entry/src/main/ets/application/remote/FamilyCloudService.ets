import { DefaultFamilyContextRepository } from '../../data/repository/DefaultFamilyContextRepository';
import { StudentProfile } from '../../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../../domain/port/FamilyContextRepository';
import { BackendSession } from './BackendSession';
import { RemoteStudent, StudentRemoteApi } from './StudentRemoteApi';

export class FamilyCloudService {
  static readonly instance: FamilyCloudService = new FamilyCloudService();
  private readonly familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance;
  private constructor() {}

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
        textbookSummary: item.textbookSummary
      });
    }
    this.familyContext.replaceStudents(students);
  }
}
