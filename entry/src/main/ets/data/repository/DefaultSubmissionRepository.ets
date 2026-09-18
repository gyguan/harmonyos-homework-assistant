import { HomeworkStore } from '../HomeworkStore';
import { Submission } from '../../domain/model/HomeworkModels';
import { SubmissionRepository } from '../../domain/port/SubmissionRepository';

export class DefaultSubmissionRepository implements SubmissionRepository {
  static readonly instance: DefaultSubmissionRepository = new DefaultSubmissionRepository();

  private constructor() {}

  listCached(assignmentId: string): Submission[] {
    let result: Submission[] = [];
    for (let item of HomeworkStore.instance.getSubmissionsForAssignment(assignmentId)) {
      result.push(this.cloneSubmission(item));
    }
    return result;
  }

  recordImages(assignmentId: string, photoUris: string[], submittedAtText: string): boolean {
    return HomeworkStore.instance.submitImages(assignmentId, photoUris.slice(), submittedAtText);
  }

  private cloneSubmission(value: Submission): Submission {
    return {
      id: value.id,
      assignmentId: value.assignmentId,
      type: value.type,
      photoUris: value.photoUris.slice(),
      fileLabel: value.fileLabel,
      submittedAtText: value.submittedAtText
    };
  }
}
