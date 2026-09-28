import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeGenerationRepository } from '../../../data/repository/DefaultPracticeGenerationRepository';
import { StudentProfile } from '../../../domain/model/HomeworkModels';
import {
  PracticeDifficulty,
  PracticeGenerationDraft,
  PracticeGenerationRequest,
  PracticeGenerationResult,
  PracticePaper,
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
  ): Promise<PracticePaper> {
    return this.repository.publish(generationId, scope, targetStudentIds);
  }

  incompatibility(student: StudentProfile, paper: PracticeGenerationDraft): string {
    if (PracticeTaxonomy.gradeFromStudentProfile(student.grade) !== paper.grade) return '年级不匹配';
    if (PracticeTaxonomy.semesterFromStudentProfile(student.semester) !== paper.semester) return '学期不匹配';
    if (paper.track === PracticeTrack.TEXTBOOK_SYNC) {
      let reference = this.normalizeTextbook(this.familyContext.getStudent().textbookSummary);
      let target = this.normalizeTextbook(student.textbookSummary);
      if (target.length === 0) return '未配置教材';
      if (target !== reference) return '教材配置不一致';
    }
    return '';
  }

  private normalizeTextbook(value: string): string {
    return value.replace(/\s+/g, '').trim().toLowerCase();
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
