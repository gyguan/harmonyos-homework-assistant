import { AppSettings, StudentProfile } from '../model/HomeworkModels';

export interface FamilyContextRepository {
  getStudent(): StudentProfile;
  getStudents(): StudentProfile[];
  getSettings(): AppSettings;
  getActiveStudentId(): string;
  setActiveStudent(studentId: string): boolean;
  replaceStudents(students: StudentProfile[]): void;
  updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean): void;
}
