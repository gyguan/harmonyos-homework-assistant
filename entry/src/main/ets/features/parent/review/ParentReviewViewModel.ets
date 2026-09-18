import { AssignmentReviewDecision } from '../../../domain/model/AssignmentReviewDecision';
import { Assignment } from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';

export class ParentReviewViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository) {
    this.repository = repository;
  }

  assignment(assignmentId: string): Assignment | null {
    return this.repository.getCached(assignmentId);
  }

  updateDetails(assignment: Assignment): Promise<Assignment> {
    return this.repository.updateDetails(assignment);
  }

  approve(assignmentId: string, note: string): Promise<Assignment> {
    return this.repository.review(assignmentId, AssignmentReviewDecision.APPROVE, note.trim());
  }

  returnForRework(assignmentId: string, note: string): Promise<Assignment> {
    let normalized = note.trim();
    if (normalized.length === 0) throw new Error('退回订正时请填写原因');
    return this.repository.review(assignmentId, AssignmentReviewDecision.RETURN_REWORK, normalized);
  }
}
