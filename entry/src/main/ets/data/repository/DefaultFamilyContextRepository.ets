import { HomeworkStore } from '../HomeworkStore';
import { AppSettings, StudentProfile } from '../../domain/model/HomeworkModels';
import { FamilyContextRepository } from '../../domain/port/FamilyContextRepository';

export class DefaultFamilyContextRepository implements FamilyContextRepository {
  static readonly instance: DefaultFamilyContextRepository = new DefaultFamilyContextRepository();

  private constructor() {}

  getStudent(): StudentProfile {
    return this.cloneStudent(HomeworkStore.instance.getStudent());
  }

  getStudents(): StudentProfile[] {
    let result: StudentProfile[] = [];
    for (let student of HomeworkStore.instance.getStudents()) result.push(this.cloneStudent(student));
    return result;
  }

  getSettings(): AppSettings {
    let settings = HomeworkStore.instance.getSettings();
    return {
      students: this.getStudents(),
      activeStudentId: settings.activeStudentId,
      tutorGuidanceFirst: settings.tutorGuidanceFirst,
      directAnswerAllowed: settings.directAnswerAllowed
    };
  }

  updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean): void {
    HomeworkStore.instance.updateTutorSettings(tutorGuidanceFirst, directAnswerAllowed);
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
