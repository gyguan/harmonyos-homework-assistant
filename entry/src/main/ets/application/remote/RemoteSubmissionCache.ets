import { RemoteSubmission } from './RemoteSubmissionApi';

export class RemoteSubmissionCache {
  static readonly instance: RemoteSubmissionCache = new RemoteSubmissionCache();
  private values: Map<string, RemoteSubmission[]> = new Map<string, RemoteSubmission[]>();

  private constructor() {}

  replace(assignmentId: string, submissions: RemoteSubmission[]): void {
    this.values.set(assignmentId, submissions.slice());
  }

  get(assignmentId: string): RemoteSubmission[] {
    let submissions = this.values.get(assignmentId);
    return submissions === undefined ? [] : submissions.slice();
  }

  clear(): void {
    this.values.clear();
  }
}
