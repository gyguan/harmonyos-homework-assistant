import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeAttemptSummary,
  PracticeGrade,
  PracticePaper,
  PracticePassFilter,
  PracticeSemester,
  PracticeSubject,
  PracticeTrack,
  PracticeTrackFilter,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';
import { PracticePassPolicy } from '../../../domain/service/PracticePassPolicy';

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

  passFilterLabel(filter: PracticePassFilter): string {
    return PracticeTaxonomy.passFilterLabel(filter);
  }

  listAttempts(): Promise<PracticeAttemptSummary[]> {
    return this.practiceRepository.listAttempts(this.familyContext.getActiveStudentId(), '');
  }

  passedPaperKeys(attempts: PracticeAttemptSummary[]): string[] {
    return PracticePassPolicy.passedPaperKeys(attempts);
  }

  isPaperPassed(paper: PracticePaper, passedPaperKeys: string[]): boolean {
    return PracticePassPolicy.isPaperPassed(paper, passedPaperKeys);
  }

  filterByPass(
    papers: PracticePaper[],
    filter: PracticePassFilter,
    passedPaperKeys: string[]
  ): PracticePaper[] {
    if (filter === PracticePassFilter.ALL) return papers.slice();
    let result: PracticePaper[] = [];
    for (let paper of papers) {
      let passed = this.isPaperPassed(paper, passedPaperKeys);
      if (filter === PracticePassFilter.PASSED && passed) result.push(paper);
      if (filter === PracticePassFilter.NOT_PASSED && !passed) result.push(paper);
    }
    return result;
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
