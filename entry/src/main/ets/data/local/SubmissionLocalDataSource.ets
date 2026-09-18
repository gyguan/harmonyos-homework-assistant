import { HomeworkStore } from '../HomeworkStore';
import { Submission } from '../../domain/model/HomeworkModels';

export interface SubmissionLocalDataSource {
  listSubmissions(assignmentId: string): Submission[];
  submitImages(assignmentId: string, photoUris: string[], submittedAtText: string): boolean;
}

export class DefaultSubmissionLocalDataSource implements SubmissionLocalDataSource {
  static readonly instance: DefaultSubmissionLocalDataSource =
    new DefaultSubmissionLocalDataSource();

  private constructor() {}

  listSubmissions(assignmentId: string): Submission[] {
    return HomeworkStore.instance.getSubmissionsForAssignment(assignmentId).slice();
  }

  submitImages(assignmentId: string, photoUris: string[], submittedAtText: string): boolean {
    return HomeworkStore.instance.submitImages(assignmentId, photoUris, submittedAtText);
  }
}
