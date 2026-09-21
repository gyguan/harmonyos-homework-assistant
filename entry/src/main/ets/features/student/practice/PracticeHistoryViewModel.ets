import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticeSubject
} from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';

export enum PracticeHistoryStatusFilter {
  ALL = 'ALL',
  SUBMITTED = 'SUBMITTED',
  IN_PROGRESS = 'IN_PROGRESS'
}

export enum PracticeHistorySubjectFilter {
  ALL = 'ALL',
  CHINESE = 'CHINESE',
  MATH = 'MATH',
  ENGLISH = 'ENGLISH'
}

export class PracticeHistoryStatistics {
  completedCount: number;
  correctRate: number;
  averageElapsedSeconds: number;

  constructor(completedCount: number = 0, correctRate: number = 0, averageElapsedSeconds: number = 0) {
    this.completedCount = completedCount;
    this.correctRate = correctRate;
    this.averageElapsedSeconds = averageElapsedSeconds;
  }
}

export class PracticeHistoryViewModel {
  private readonly repository: PracticeRepository;
  private readonly familyContext: FamilyContextRepository;

  constructor(
    repository: PracticeRepository = DefaultPracticeRepository.instance,
    familyContext: FamilyContextRepository = DefaultFamilyContextRepository.instance
  ) {
    this.repository = repository;
    this.familyContext = familyContext;
  }

  list(paperId: string = ''): Promise<PracticeAttemptSummary[]> {
    return this.repository.listAttempts(this.familyContext.getActiveStudentId(), paperId);
  }

  filter(
    attempts: PracticeAttemptSummary[],
    status: PracticeHistoryStatusFilter,
    subject: PracticeHistorySubjectFilter
  ): PracticeAttemptSummary[] {
    let result: PracticeAttemptSummary[] = [];
    for (let item of attempts) {
      if (!this.matchesStatus(item, status)) continue;
      if (!this.matchesSubject(item, subject)) continue;
      result.push(item);
    }
    return result;
  }

  statistics(
    attempts: PracticeAttemptSummary[],
    subject: PracticeHistorySubjectFilter
  ): PracticeHistoryStatistics {
    let completedCount = 0;
    let totalCorrect = 0;
    let totalQuestions = 0;
    let totalElapsedSeconds = 0;

    for (let item of attempts) {
      if (item.status !== PracticeAttemptStatus.SUBMITTED) continue;
      if (!this.matchesSubject(item, subject)) continue;
      completedCount++;
      totalCorrect += item.correctCount;
      totalQuestions += item.maxScore;
      totalElapsedSeconds += Math.max(0, item.elapsedSeconds);
    }

    let correctRate = totalQuestions > 0 ? Math.round(totalCorrect * 100 / totalQuestions) : 0;
    let averageElapsedSeconds =
      completedCount > 0 ? Math.round(totalElapsedSeconds / completedCount) : 0;
    return new PracticeHistoryStatistics(completedCount, correctRate, averageElapsedSeconds);
  }

  showStatistics(status: PracticeHistoryStatusFilter): boolean {
    return status !== PracticeHistoryStatusFilter.IN_PROGRESS;
  }

  statusLabel(item: PracticeAttemptSummary): string {
    return item.status === PracticeAttemptStatus.SUBMITTED ? '已完成' : '进行中';
  }

  statusFilterLabel(status: PracticeHistoryStatusFilter): string {
    if (status === PracticeHistoryStatusFilter.SUBMITTED) return '已完成';
    if (status === PracticeHistoryStatusFilter.IN_PROGRESS) return '进行中';
    return '全部';
  }

  subjectFilterLabel(subject: PracticeHistorySubjectFilter): string {
    if (subject === PracticeHistorySubjectFilter.CHINESE) return '语文';
    if (subject === PracticeHistorySubjectFilter.MATH) return '数学';
    if (subject === PracticeHistorySubjectFilter.ENGLISH) return '英语';
    return '全部';
  }

  modeLabel(item: PracticeAttemptSummary): string {
    return item.mode === PracticeAttemptMode.WRONG_ONLY ? '错题专项' : '完整套卷';
  }

  scoreText(item: PracticeAttemptSummary): string {
    if (item.status !== PracticeAttemptStatus.SUBMITTED) {
      return `已答 ${item.answeredCount}/${item.questionCount}`;
    }
    return `${item.score}/${item.maxScore} 分`;
  }

  correctRateText(statistics: PracticeHistoryStatistics): string {
    if (statistics.completedCount <= 0) return '--';
    return `${statistics.correctRate}%`;
  }

  averageElapsedText(statistics: PracticeHistoryStatistics): string {
    if (statistics.completedCount <= 0) return '--';
    return this.elapsedText(statistics.averageElapsedSeconds);
  }

  timeText(epochMs: number): string {
    if (epochMs <= 0) return '';
    let date = new Date(epochMs);
    let month = date.getMonth() + 1;
    let day = date.getDate();
    let hour = date.getHours();
    let minute = date.getMinutes();
    return `${date.getFullYear()}-${this.two(month)}-${this.two(day)} ${this.two(hour)}:${this.two(minute)}`;
  }

  elapsedText(seconds: number): string {
    let safeSeconds = Math.max(0, seconds);
    let minutes = Math.floor(safeSeconds / 60);
    let rest = safeSeconds % 60;
    if (minutes <= 0) return `${rest}秒`;
    if (rest <= 0) return `${minutes}分`;
    return `${minutes}分${rest}秒`;
  }

  private matchesStatus(item: PracticeAttemptSummary, status: PracticeHistoryStatusFilter): boolean {
    if (status === PracticeHistoryStatusFilter.SUBMITTED) {
      return item.status === PracticeAttemptStatus.SUBMITTED;
    }
    if (status === PracticeHistoryStatusFilter.IN_PROGRESS) {
      return item.status === PracticeAttemptStatus.IN_PROGRESS;
    }
    return true;
  }

  private matchesSubject(item: PracticeAttemptSummary, subject: PracticeHistorySubjectFilter): boolean {
    if (subject === PracticeHistorySubjectFilter.CHINESE) return item.subject === PracticeSubject.CHINESE;
    if (subject === PracticeHistorySubjectFilter.MATH) return item.subject === PracticeSubject.MATH;
    if (subject === PracticeHistorySubjectFilter.ENGLISH) return item.subject === PracticeSubject.ENGLISH;
    return true;
  }

  private two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
