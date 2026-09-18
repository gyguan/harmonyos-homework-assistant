import { HomeworkStore } from '../HomeworkStore';
import { Assignment, StudentProfile, TodaySummary } from '../../domain/model/HomeworkModels';

export interface AssignmentLocalDataSource {
  getActiveStudent(): StudentProfile;
  getActiveStudentId(): string;
  listAssignments(): Assignment[];
  getAssignment(assignmentId: string): Assignment | null;
  getTodaySummary(): TodaySummary;
  replaceAssignmentsForActiveStudent(assignments: Assignment[]): void;
  reviewAssignment(assignmentId: string, completed: boolean, note: string): boolean;
  startAssignment(assignmentId: string): boolean;
  pauseAssignment(assignmentId: string): boolean;
  markReadyToSubmit(assignmentId: string): boolean;
}

export class HomeworkStoreAssignmentLocalDataSource implements AssignmentLocalDataSource {
  static readonly instance: HomeworkStoreAssignmentLocalDataSource =
    new HomeworkStoreAssignmentLocalDataSource();

  private constructor() {}

  getActiveStudent(): StudentProfile {
    let student = HomeworkStore.instance.getStudent();
    return {
      id: student.id,
      name: student.name,
      grade: student.grade,
      className: student.className,
      semester: student.semester,
      textbookSummary: student.textbookSummary
    };
  }

  getActiveStudentId(): string {
    return HomeworkStore.instance.getActiveStudentId();
  }

  listAssignments(): Assignment[] {
    return HomeworkStore.instance.getAssignments().slice();
  }

  getAssignment(assignmentId: string): Assignment | null {
    return HomeworkStore.instance.getAssignment(assignmentId);
  }

  getTodaySummary(): TodaySummary {
    return HomeworkStore.instance.getTodaySummary();
  }

  replaceAssignmentsForActiveStudent(assignments: Assignment[]): void {
    HomeworkStore.instance.replaceAssignmentsForActiveStudent(assignments);
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
