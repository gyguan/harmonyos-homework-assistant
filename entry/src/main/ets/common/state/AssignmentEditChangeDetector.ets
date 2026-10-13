import { Subject } from '../../domain/model/HomeworkModels';

export interface AssignmentEditValues {
  subject: Subject;
  title: string;
  instruction: string;
  taskDate: string;
  expectedMinutes: number;
  textbookRef: string;
}

export class AssignmentEditChangeDetector {
  static hasChanges(original: AssignmentEditValues, current: AssignmentEditValues): boolean {
    return original.subject !== current.subject ||
      original.title !== current.title ||
      original.instruction !== current.instruction ||
      original.taskDate !== current.taskDate ||
      original.expectedMinutes !== current.expectedMinutes ||
      original.textbookRef !== current.textbookRef;
  }
}
