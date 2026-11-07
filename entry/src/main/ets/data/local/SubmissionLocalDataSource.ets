import { HomeworkStore } from '../HomeworkStore';
import { Submission } from '../../domain/model/HomeworkModels';

export interface SubmissionLocalDataSource {
  listSubmissions(assignmentId: string): Submission[];
  listAllSubmissions(): Submission[];
  submitImages(assignmentId: string, photoUris: string[], submittedAtText: string): boolean;
  submitAudio(assignmentId: string, audioUri: string, durationMs: number, submittedAtText: string): boolean;
  submitMixed(assignmentId: string, photoUris: string[], audioUri: string, durationMs: number,
    submittedAtText: string): boolean;
}

export class DefaultSubmissionLocalDataSource implements SubmissionLocalDataSource {
  static readonly instance: DefaultSubmissionLocalDataSource =
    new DefaultSubmissionLocalDataSource();

  private constructor() {}

  listSubmissions(assignmentId: string): Submission[] {
    return HomeworkStore.instance.getSubmissionsForAssignment(assignmentId).slice();
  }

  listAllSubmissions(): Submission[] {
    return HomeworkStore.instance.listAllSubmissions();
  }

  submitImages(assignmentId: string, photoUris: string[], submittedAtText: string): boolean {
    return HomeworkStore.instance.submitImages(assignmentId, photoUris, submittedAtText);
  }

  submitAudio(assignmentId: string, audioUri: string, durationMs: number, submittedAtText: string): boolean {
    return HomeworkStore.instance.submitAudio(assignmentId, audioUri, durationMs, submittedAtText);
  }

  submitMixed(assignmentId: string, photoUris: string[], audioUri: string, durationMs: number,
    submittedAtText: string): boolean {
    return HomeworkStore.instance.submitMixed(assignmentId, photoUris, audioUri, durationMs, submittedAtText);
  }
}
