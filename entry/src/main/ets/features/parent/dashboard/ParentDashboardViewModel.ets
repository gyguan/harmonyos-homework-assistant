import { DefaultAssignmentRepository } from '../../../data/repository/DefaultAssignmentRepository';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';
import { AssignmentAttentionPolicy } from '../../../domain/service/AssignmentAttentionPolicy';

export class ParentDashboardViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository = DefaultAssignmentRepository.instance) {
    this.repository = repository;
  }

  attentionText(): string {
    return AssignmentAttentionPolicy.parent(this.repository.listCached());
  }
}
