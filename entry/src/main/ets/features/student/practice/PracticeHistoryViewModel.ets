import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticePassFilter,
  PracticeSubject,
  PracticeTaxonomy
} from '../../../domain/model/practice/PracticeModels';
import {
  PracticeHistorySubjectFilter,
  PracticeHistoryTimeFilter
} from '../../../domain/model/PracticeHistoryFilter';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';
import { PracticePassPolicy } from '../../../domain/service/PracticePassPolicy';

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
    subject: PracticeHistorySubjectFilter,
    time: PracticeHistoryTimeFilter,
    pass: PracticePassFilter,
    nowEpochMs: number
  ): PracticeAttemptSummary[] {
    let result: PracticeAttemptSummary[] = [];
    for (let item of attempts) {
      if (!this.matchesSubject(item, subject)) continue;
      if (!this.matchesTime(item, time, nowEpochMs)) continue;
      if (!this.matchesPass(item, pass)) continue;
      result.push(item);
    }
    return result;
  }

  statistics(attempts: PracticeAttemptSummary[]): PracticeHistoryStatistics {
    let completedCount = 0;
    let totalCorrect = 0;
    let totalQuestions = 0;
    let totalElapsedSeconds = 0;

    for (let item of attempts) {
      if (item.status !== PracticeAttemptStatus.SUBMITTED) continue;
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

  subjectFilterLabel(subject: PracticeHistorySubjectFilter): string {
    if (subject === PracticeHistorySubjectFilter.CHINESE) return '语文';
    if (subject === PracticeHistorySubjectFilter.MATH) return '数学';
    if (subject === PracticeHistorySubjectFilter.ENGLISH) return '英语';
    return '全部科目';
  }

  timeFilterLabel(time: PracticeHistoryTimeFilter): string {
    if (time === PracticeHistoryTimeFilter.LAST_7_DAYS) return '近7天';
    if (time === PracticeHistoryTimeFilter.LAST_30_DAYS) return '近30天';
    if (time === PracticeHistoryTimeFilter.LAST_90_DAYS) return '近90天';
    return '全部时间';
  }

  passFilterLabel(filter: PracticePassFilter): string {
    return PracticeTaxonomy.passFilterLabel(filter);
  }

  modeLabel(item: PracticeAttemptSummary): string {
    return item.mode === PracticeAttemptMode.WRONG_ONLY ? '错题专项' : '完整套卷';
  }

  recordStatusLabel(item: PracticeAttemptSummary): string {
    if (item.status !== PracticeAttemptStatus.SUBMITTED) return '进行中';
    if (item.mode === PracticeAttemptMode.WRONG_ONLY) return '专项练习';
    return PracticePassPolicy.isPassedAttempt(item) ? '已通过' : '未通过';
  }

  isPassed(item: PracticeAttemptSummary): boolean {
    return PracticePassPolicy.isPassedAttempt(item);
  }

  isWrongOnly(item: PracticeAttemptSummary): boolean {
    return item.mode === PracticeAttemptMode.WRONG_ONLY;
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

  private matchesSubject(item: PracticeAttemptSummary, subject: PracticeHistorySubjectFilter): boolean {
    if (subject === PracticeHistorySubjectFilter.CHINESE) return item.subject === PracticeSubject.CHINESE;
    if (subject === PracticeHistorySubjectFilter.MATH) return item.subject === PracticeSubject.MATH;
    if (subject === PracticeHistorySubjectFilter.ENGLISH) return item.subject === PracticeSubject.ENGLISH;
    return true;
  }

  private matchesTime(
    item: PracticeAttemptSummary,
    time: PracticeHistoryTimeFilter,
    nowEpochMs: number
  ): boolean {
    if (time === PracticeHistoryTimeFilter.ALL) return true;
    let days = 7;
    if (time === PracticeHistoryTimeFilter.LAST_30_DAYS) days = 30;
    if (time === PracticeHistoryTimeFilter.LAST_90_DAYS) days = 90;
    let startEpochMs = nowEpochMs - days * 24 * 60 * 60 * 1000;
    return item.startedAtEpochMs >= startEpochMs && item.startedAtEpochMs <= nowEpochMs;
  }

  private matchesPass(item: PracticeAttemptSummary, pass: PracticePassFilter): boolean {
    return PracticePassPolicy.matchesAttemptPassFilter(item, pass);
  }

  private two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
