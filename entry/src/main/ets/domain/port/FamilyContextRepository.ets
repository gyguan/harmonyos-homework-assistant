import { AppSettings, StudentProfile } from '../model/HomeworkModels';

export interface FamilyContextRepository {
  getStudent(): StudentProfile;
  getStudents(): StudentProfile[];
  getSettings(): AppSettings;
  updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean): void;
}
