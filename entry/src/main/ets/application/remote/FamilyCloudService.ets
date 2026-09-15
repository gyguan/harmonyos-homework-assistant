import { HomeworkStore } from '../../data/HomeworkStore';
import { StudentProfile } from '../../domain/model/HomeworkModels';
import { BackendSession } from './BackendSession';
import { RemoteStudent, StudentRemoteApi } from './StudentRemoteApi';

export class FamilyCloudService {
  static readonly instance: FamilyCloudService = new FamilyCloudService();
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
      if (synced) HomeworkStore.instance.setActiveStudent(student.id);
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
    let settings = HomeworkStore.instance.getSettings();
    settings.students.splice(0, settings.students.length);
    for (let item of remote) {
      settings.students.push({
        id: item.id,
        name: item.name,
        grade: item.grade,
        className: item.className,
        semester: item.semester,
        textbookSummary: item.textbookSummary
      });
    }
    let activeExists = false;
    for (let student of settings.students) if (student.id === settings.activeStudentId) activeExists = true;
    if (!activeExists && settings.students.length > 0) settings.activeStudentId = settings.students[0].id;
    // Re-saving the current child import is an intentional lightweight persistence touch: it keeps
    // HomeworkStore as the sole owner of the snapshot while persisting the updated settings object.
    HomeworkStore.instance.replaceRawImport(HomeworkStore.instance.getRawImport());
  }
}
