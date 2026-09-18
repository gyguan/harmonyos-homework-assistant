import { Submission } from '../model/HomeworkModels';

export interface SubmissionRepository {
  listCached(assignmentId: string): Submission[];
  recordImages(assignmentId: string, photoUris: string[], submittedAtText: string): boolean;
}
