import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import { DefaultPracticeGenerationRepository } from '../../../data/repository/DefaultPracticeGenerationRepository';
import {
  PracticeAttempt,
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticeGenerationRequest,
  PracticePaper,
  PracticePublishScope,
  PracticeResult
} from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';
import { PracticeGenerationRepository } from '../../../domain/port/PracticeGenerationRepository';

export interface PracticeProgressSummary {
  previousCorrectCount: number;
  previousPercent: number;
  correctDelta: number;
  percentDelta: number;
}

export class PracticeResultViewModel {
  private readonly repository: PracticeRepository;
  private readonly familyContext: FamilyContextRepository;
  private readonly generationRepository: PracticeGenerationRepository;
  private cachedPaperId: string = '';
  private cachedPaperVersion: number = 0;
  private cachedStudentId: string = '';
  private cachedAttempts: PracticeAttemptSummary[] | null = null;

  constructor(
    repository: PracticeRepository = DefaultPracticeRepository.instance,
    familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance,
    generationRepository: PracticeGenerationRepository = DefaultPracticeGenerationRepository.instance
  ) {
    this.repository = repository;
    this.familyContext = familyContext;
    this.generationRepository = generationRepository;
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

  async reinforceFive(attemptId: string): Promise<PracticeAttempt> {
    let result = await this.repository.getResult(attemptId);
    if (result.wrongCount <= 0) return this.repository.repeatAttempt(attemptId);

    let attempt = await this.repository.getAttempt(attemptId);
    let studentId = attempt.studentId;
    if (studentId !== this.familyContext.getActiveStudentId()) {
      throw new Error('已切换孩子，请返回当前孩子后再开始巩固练习');
    }

    try {
      let paper = await this.repository.getPaper(result.paperId, result.paperVersion);
      if (paper === null) throw new Error('练习套卷不存在');

      let wrongQuestionIds: Set<string> = new Set<string>();
      for (let item of result.questions) {
        if (!item.correct) wrongQuestionIds.add(item.questionId);
      }

      let tags: string[] = [];
      let seenTags: Set<string> = new Set<string>();
      for (let question of attempt.questions) {
        if (!wrongQuestionIds.has(question.id)) continue;
        for (let tag of question.tags) {
          let normalized = tag.trim();
          if (normalized.length === 0 || seenTags.has(normalized)) continue;
          seenTags.add(normalized);
          tags.push(normalized);
          if (tags.length >= 6) break;
        }
        if (tags.length >= 6) break;
      }

      let focus = tags.length > 0 ? tags.join('、') : '本次做错的题型和方法';
      let input: PracticeGenerationRequest = {
        subject: paper.subject,
        track: paper.track,
        difficulty: paper.difficulty,
        questionCount: 5,
        requirement: `围绕${focus}生成 5 道同类巩固题，不重复原题，难度保持接近，提示要帮助理解而不是直接给答案。`
      };
      let generated = await this.generationRepository.generate(studentId, input);
      if (generated.status !== 'READY' || generated.paper === null) {
        throw new Error('AI巩固练习尚未准备好');
      }
      if (studentId !== this.familyContext.getActiveStudentId()) {
        throw new Error('已切换孩子，请返回当前孩子后再开始巩固练习');
      }

      let published = await this.generationRepository.publish(
        generated.generationId, PracticePublishScope.CURRENT, []);
      if (studentId !== this.familyContext.getActiveStudentId()) {
        throw new Error('已切换孩子，请返回当前孩子后再开始巩固练习');
      }
      return this.repository.startAttempt(studentId, published.paper.id, published.paper.version);
    } catch {
      if (studentId !== this.familyContext.getActiveStudentId()) {
        throw new Error('已切换孩子，请返回当前孩子后再开始巩固练习');
      }
      return this.repository.retryWrongAttempt(attemptId);
    }
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
