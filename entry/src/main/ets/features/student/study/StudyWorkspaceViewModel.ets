import { AssignmentAction } from '../../../domain/model/AssignmentAction';
import { Assignment } from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';

export class StudyWorkspaceViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository) {
    this.repository = repository;
  }

  assignment(assignmentId: string): Assignment | null {
    return this.repository.getCached(assignmentId);
  }

  studentId(): string {
    return this.repository.getActiveStudent().id;
  }

  async performAction(assignmentId: string, action: AssignmentAction): Promise<Assignment> {
    return this.repository.performAction(assignmentId, action);
  }
}
