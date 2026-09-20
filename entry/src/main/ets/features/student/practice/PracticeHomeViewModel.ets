import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeGrade,
  PracticePaper,
  PracticeSubject,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';

export class PracticeHomeViewModel {
  private readonly practiceRepository: PracticeRepository;
  private readonly familyContext: FamilyContextRepository;

  constructor(
    practiceRepository: PracticeRepository = DefaultPracticeRepository.instance,
    familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance
  ) {
    this.practiceRepository = practiceRepository;
    this.familyContext = familyContext;
  }

  defaultGrade(): PracticeGrade {
    return PracticeTaxonomy.gradeFromStudentProfile(this.familyContext.getStudent().grade);
  }

  grades(): PracticeGrade[] {
    return PracticeTaxonomy.grades();
  }

  subjects(): PracticeSubject[] {
    return PracticeTaxonomy.subjects();
  }

  gradeLabel(grade: PracticeGrade): string {
    return PracticeTaxonomy.gradeLabel(grade);
  }

  subjectLabel(subject: PracticeSubject): string {
    return PracticeTaxonomy.subjectLabel(subject);
  }

  difficultyLabel(paper: PracticePaper): string {
    return PracticeTaxonomy.difficultyLabel(paper.difficulty);
  }

  listPapers(grade: PracticeGrade, subject: PracticeSubject): Promise<PracticePaper[]> {
    return this.practiceRepository.listPapers(grade, subject);
  }
}
