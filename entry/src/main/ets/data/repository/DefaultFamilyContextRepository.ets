import { AppSettings, StudentProfile } from '../../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../../domain/port/FamilyContextRepository';
import { DefaultFamilyContextLocalDataSource, FamilyContextLocalDataSource } from '../local/FamilyContextLocalDataSource';

export class DefaultFamilyContextRepository implements FamilyContextRepository {
  static readonly instance: DefaultFamilyContextRepository = new DefaultFamilyContextRepository();
  private readonly local: FamilyContextLocalDataSource = DefaultFamilyContextLocalDataSource.instance;

  private constructor() {}

  getStudent(): StudentProfile {
    return this.cloneStudent(this.local.getStudent());
  }

  getStudents(): StudentProfile[] {
    let result: StudentProfile[] = [];
    for (let student of this.local.getStudents()) result.push(this.cloneStudent(student));
    return result;
  }

  getActiveStudentId(): string {
    return this.local.getActiveStudentId();
  }

  setActiveStudent(studentId: string): boolean {
    return this.local.setActiveStudent(studentId);
  }

  replaceStudents(students: StudentProfile[]): void {
    let copies: StudentProfile[] = [];
    for (let student of students) copies.push(this.cloneStudent(student));
    this.local.replaceStudents(copies);
  }

  getSettings(): AppSettings {
    let settings = this.local.getSettings();
    return {
      students: this.getStudents(),
      activeStudentId: settings.activeStudentId,
      tutorGuidanceFirst: settings.tutorGuidanceFirst,
      directAnswerAllowed: settings.directAnswerAllowed
    };
  }

  updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean): void {
    this.local.updateTutorSettings(tutorGuidanceFirst, directAnswerAllowed);
  }

  private cloneStudent(student: StudentProfile): StudentProfile {
    return {
      id: student.id,
      name: student.name,
      grade: student.grade,
      className: student.className,
      semester: student.semester,
      textbookSummary: student.textbookSummary
    };
  }
}
