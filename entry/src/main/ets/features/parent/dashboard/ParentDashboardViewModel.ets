import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';
import { AssignmentAttentionKind, AssignmentAttentionPolicy, AssignmentAttentionResult } from '../../../domain/service/AssignmentAttentionPolicy';

export class ParentDashboardViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository = DefaultAssignmentRepository.instance) {
    this.repository = repository;
  }

  attention(): AssignmentAttentionResult {
    return AssignmentAttentionPolicy.parentResult(this.repository.listCached());
  }

  attentionText(): string {
    return this.attention().text;
  }

  attentionKind(): AssignmentAttentionKind {
    return this.attention().kind;
  }
}
