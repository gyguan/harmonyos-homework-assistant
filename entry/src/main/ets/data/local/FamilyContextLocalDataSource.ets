import { HomeworkStore } from '../HomeworkStore';
import { AppSettings, StudentProfile } from '../../domain/model/HomeworkModels';

export interface FamilyContextLocalDataSource {
  getStudent(): StudentProfile;
  getStudents(): StudentProfile[];
  getSettings(): AppSettings;
  getActiveStudentId(): string;
  setActiveStudent(studentId: string): boolean;
  replaceStudents(students: StudentProfile[]): void;
  updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean): void;
}

export class DefaultFamilyContextLocalDataSource implements FamilyContextLocalDataSource {
  static readonly instance: DefaultFamilyContextLocalDataSource =
    new DefaultFamilyContextLocalDataSource();

  private constructor() {}

  getStudent(): StudentProfile {
    return HomeworkStore.instance.getStudent();
  }

  getStudents(): StudentProfile[] {
    return HomeworkStore.instance.getStudents();
  }

  getSettings(): AppSettings {
    return HomeworkStore.instance.getSettings();
  }

  getActiveStudentId(): string {
    return HomeworkStore.instance.getActiveStudentId();
  }

  setActiveStudent(studentId: string): boolean {
    return HomeworkStore.instance.setActiveStudent(studentId);
  }

  replaceStudents(students: StudentProfile[]): void {
    HomeworkStore.instance.replaceStudents(students);
  }

  updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean): void {
    HomeworkStore.instance.updateTutorSettings(tutorGuidanceFirst, directAnswerAllowed);
  }
}
