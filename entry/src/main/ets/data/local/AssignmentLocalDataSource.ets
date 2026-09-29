import { HomeworkStore } from '../HomeworkStore';
import { Assignment, StudentProfile, TodaySummary } from '../../domain/model/HomeworkModels';

export interface AssignmentLocalDataSource {
  getActiveStudent(): StudentProfile;
  getActiveStudentId(): string;
  listAssignments(): Assignment[];
  listAssignmentsForStudent(studentId: string): Assignment[];
  getAssignment(assignmentId: string): Assignment | null;
  getAssignmentForStudent(studentId: string, assignmentId: string): Assignment | null;
  getTodaySummary(): TodaySummary;
  replaceAssignmentsForActiveStudent(assignments: Assignment[]): void;
  replaceAssignmentsForStudent(studentId: string, assignments: Assignment[]): void;
  reviewAssignment(assignmentId: string, completed: boolean, note: string): boolean;
  startAssignment(assignmentId: string): boolean;
  pauseAssignment(assignmentId: string): boolean;
  markReadyToSubmit(assignmentId: string): boolean;
}

export class DefaultAssignmentLocalDataSource implements AssignmentLocalDataSource {
  static readonly instance: DefaultAssignmentLocalDataSource =
    new DefaultAssignmentLocalDataSource();

  private constructor() {}

  getActiveStudent(): StudentProfile {
    let student = HomeworkStore.instance.getStudent();
    return {
      id: student.id,
      name: student.name,
      grade: student.grade,
      className: student.className,
      semester: student.semester,
      chineseTextbook: student.chineseTextbook,
      mathTextbook: student.mathTextbook,
      englishTextbook: student.englishTextbook,
      otherTextbooks: student.otherTextbooks,
      textbookSummary: student.textbookSummary
    };
  }

  getActiveStudentId(): string {
    return HomeworkStore.instance.getActiveStudentId();
  }

  listAssignments(): Assignment[] {
    return HomeworkStore.instance.getAssignments().slice();
  }

  listAssignmentsForStudent(studentId: string): Assignment[] {
    return HomeworkStore.instance.getAssignmentsForStudent(studentId);
  }

  getAssignment(assignmentId: string): Assignment | null {
    return HomeworkStore.instance.getAssignment(assignmentId);
  }

  getAssignmentForStudent(studentId: string, assignmentId: string): Assignment | null {
    return HomeworkStore.instance.getAssignmentForStudent(studentId, assignmentId);
  }

  getTodaySummary(): TodaySummary {
    return HomeworkStore.instance.getTodaySummary();
  }

  replaceAssignmentsForActiveStudent(assignments: Assignment[]): void {
    HomeworkStore.instance.replaceAssignmentsForActiveStudent(assignments);
  }

  replaceAssignmentsForStudent(studentId: string, assignments: Assignment[]): void {
    HomeworkStore.instance.replaceAssignmentsForStudent(studentId, assignments);
  }

  reviewAssignment(assignmentId: string, completed: boolean, note: string): boolean {
    return HomeworkStore.instance.reviewAssignment(assignmentId, completed, note);
  }

  startAssignment(assignmentId: string): boolean {
    return HomeworkStore.instance.startAssignment(assignmentId);
  }

  pauseAssignment(assignmentId: string): boolean {
    return HomeworkStore.instance.pauseAssignment(assignmentId);
  }

  markReadyToSubmit(assignmentId: string): boolean {
    return HomeworkStore.instance.markReadyToSubmit(assignmentId);
  }
}
