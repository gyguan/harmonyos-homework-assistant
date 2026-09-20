import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import { PracticeAttempt, PracticePaper } from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';

export class PracticePaperDetailViewModel {
  private readonly repository: PracticeRepository;
  private readonly familyContext: FamilyContextRepository;

  constructor(
    repository: PracticeRepository = DefaultPracticeRepository.instance,
    familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance
  ) {
    this.repository = repository;
    this.familyContext = familyContext;
  }

  getPaper(paperId: string, version: number): Promise<PracticePaper | null> {
    return this.repository.getPaper(paperId, version);
  }

  start(paperId: string, version: number): Promise<PracticeAttempt> {
    return this.repository.startAttempt(this.familyContext.getActiveStudentId(), paperId, version);
  }
}
