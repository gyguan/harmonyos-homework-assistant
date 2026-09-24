import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeAttempt,
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticePaper,
  PracticeResult
} from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';

export interface PracticeProgressSummary {
  previousCorrectCount: number;
  previousPercent: number;
  correctDelta: number;
  percentDelta: number;
}

export class PracticeResultViewModel {
  private readonly repository: PracticeRepository;
  private readonly familyContext: FamilyContextRepository;
  private cachedPaperId: string = '';
  private cachedPaperVersion: number = 0;
  private cachedStudentId: string = '';
  private cachedAttempts: PracticeAttemptSummary[] | null = null;

  constructor(
    repository: PracticeRepository = DefaultPracticeRepository.instance,
    familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance
  ) {
    this.repository = repository;
    this.familyContext = familyContext;
  }

  load(attemptId: string): Promise<PracticeResult> {
    return this.repository.getResult(attemptId);
  }

  async paperTitle(result: PracticeResult): Promise<string> {
    let historyTitle = await this.historyPaperTitle(result);
    if (historyTitle.length > 0) return historyTitle;

    let paper: PracticePaper | null = await this.repository.getPaper(result.paperId, result.paperVersion);
    if (paper !== null && paper.title.length > 0) return paper.title;
    return result.paperId;
  }

  async progress(result: PracticeResult): Promise<PracticeProgressSummary | null> {
    if (result.mode !== PracticeAttemptMode.FULL || result.attemptNo <= 1) return null;

    try {
      let attempts = await this.attemptsForPaper(result.paperId, result.paperVersion);
      let previous: PracticeAttemptSummary | null = null;

      for (let item of attempts) {
        if (item.id === result.attemptId ||
          item.status !== PracticeAttemptStatus.SUBMITTED ||
          item.mode !== PracticeAttemptMode.FULL ||
          item.attemptNo >= result.attemptNo) {
          continue;
        }

        if (previous === null || item.attemptNo > previous.attemptNo) previous = item;
      }

      if (previous === null || previous.maxScore <= 0) return null;

      let previousPercent = Math.round(previous.score * 100 / previous.maxScore);
      let currentPercent = this.percent(result);
      return {
        previousCorrectCount: previous.correctCount,
        previousPercent: previousPercent,
        correctDelta: result.correctCount - previous.correctCount,
        percentDelta: currentPercent - previousPercent
      };
    } catch {
      return null;
    }
  }

  private async historyPaperTitle(result: PracticeResult): Promise<string> {
    try {
      let attempts = await this.attemptsForPaper(result.paperId, result.paperVersion);
      for (let item of attempts) {
        if (item.id === result.attemptId && item.paperTitle.length > 0) return item.paperTitle;
      }
      return '';
    } catch {
      return '';
    }
  }

  private async attemptsForPaper(paperId: string, paperVersion: number): Promise<PracticeAttemptSummary[]> {
    let studentId = this.familyContext.getActiveStudentId();
    if (this.cachedAttempts !== null &&
      this.cachedStudentId === studentId &&
      this.cachedPaperId === paperId &&
      this.cachedPaperVersion === paperVersion) {
      return this.cachedAttempts;
    }

    let allAttempts = await this.repository.listAttempts(studentId, paperId);
    let attempts: PracticeAttemptSummary[] = [];
    for (let item of allAttempts) {
      if (item.paperVersion === paperVersion) attempts.push(item);
    }
    this.cachedStudentId = studentId;
    this.cachedPaperId = paperId;
    this.cachedPaperVersion = paperVersion;
    this.cachedAttempts = attempts;
    return attempts;
  }

  repeat(attemptId: string): Promise<PracticeAttempt> {
    return this.repository.repeatAttempt(attemptId);
  }

  retryWrong(attemptId: string): Promise<PracticeAttempt> {
    return this.repository.retryWrongAttempt(attemptId);
  }

  percent(result: PracticeResult): number {
    if (result.maxScore <= 0) return 0;
    return Math.round(result.score * 100 / result.maxScore);
  }

  elapsedText(seconds: number): string {
    let minutes = Math.floor(seconds / 60);
    let rest = seconds % 60;
    return `${minutes}分${rest}秒`;
  }
}
