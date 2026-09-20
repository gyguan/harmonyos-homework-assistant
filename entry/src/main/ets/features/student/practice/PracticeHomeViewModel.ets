import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeGrade,
  PracticePaper,
  PracticeSemester,
  PracticeSubject,
  PracticeTrack,
  PracticeTrackFilter,
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

  defaultSemester(): PracticeSemester {
    return PracticeTaxonomy.semesterFromStudentProfile(this.familyContext.getStudent().semester);
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

  semesterLabel(semester: PracticeSemester): string {
    return PracticeTaxonomy.semesterLabel(semester);
  }

  trackLabel(track: PracticeTrack): string {
    return PracticeTaxonomy.trackLabel(track);
  }

  trackFilterLabel(track: PracticeTrackFilter): string {
    return PracticeTaxonomy.trackFilterLabel(track);
  }

  difficultyLabel(paper: PracticePaper): string {
    return PracticeTaxonomy.difficultyLabel(paper.difficulty);
  }

  listPapers(
    grade: PracticeGrade,
    subject: PracticeSubject,
    semester: PracticeSemester,
    track: PracticeTrackFilter
  ): Promise<PracticePaper[]> {
    return this.practiceRepository.listPapers(grade, subject, semester, track);
  }
}
