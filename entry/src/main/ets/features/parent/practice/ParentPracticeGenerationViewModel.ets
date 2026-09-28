import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeGenerationRepository } from '../../../data/repository/DefaultPracticeGenerationRepository';
import { StudentProfile } from '../../../domain/model/HomeworkModels';
import {
  PracticeDifficulty,
  PracticeGenerationRequest,
  PracticeGenerationResult,
  PracticePublishResult,
  PracticePublishScope,
  PracticeSubject,
  PracticeTrack,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeGenerationRepository } from '../../../domain/port/PracticeGenerationRepository';

export class ParentPracticeGenerationViewModel {
  private readonly repository: PracticeGenerationRepository;
  private readonly familyContext: FamilyContextRepository;

  constructor(
    repository: PracticeGenerationRepository = DefaultPracticeGenerationRepository.instance,
    familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance
  ) {
    this.repository = repository;
    this.familyContext = familyContext;
  }

  student(): StudentProfile {
    return this.familyContext.getStudent();
  }

  students(): StudentProfile[] {
    return this.familyContext.getStudents();
  }

  activeStudentId(): string {
    return this.familyContext.getActiveStudentId();
  }

  generate(
    subject: PracticeSubject,
    track: PracticeTrack,
    difficulty: PracticeDifficulty,
    questionCount: number,
    requirement: string
  ): Promise<PracticeGenerationResult> {
    let input: PracticeGenerationRequest = {
      subject: subject,
      track: track,
      difficulty: difficulty,
      questionCount: questionCount,
      requirement: requirement.trim()
    };
    return this.repository.generate(this.familyContext.getActiveStudentId(), input);
  }

  publish(
    generationId: string,
    scope: PracticePublishScope,
    targetStudentIds: string[]
  ): Promise<PracticePublishResult> {
    return this.repository.publish(generationId, scope, targetStudentIds);
  }

  subjectLabel(subject: PracticeSubject): string {
    return PracticeTaxonomy.subjectLabel(subject);
  }

  trackLabel(track: PracticeTrack): string {
    return PracticeTaxonomy.trackLabel(track);
  }

  difficultyLabel(difficulty: PracticeDifficulty): string {
    return PracticeTaxonomy.difficultyLabel(difficulty);
  }
}
