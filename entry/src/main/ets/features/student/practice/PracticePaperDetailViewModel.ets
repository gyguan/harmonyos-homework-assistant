import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import {
  PracticeAttempt,
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticePaper
} from '../../../domain/model/practice/PracticeModels';
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

  listAttempts(paperId: string): Promise<PracticeAttemptSummary[]> {
    return this.repository.listAttempts(this.familyContext.getActiveStudentId(), paperId);
  }

  recentAttempts(attempts: PracticeAttemptSummary[]): PracticeAttemptSummary[] {
    if (attempts.length <= 3) return attempts;
    return attempts.slice(0, 3);
  }

  start(paperId: string, version: number): Promise<PracticeAttempt> {
    return this.repository.startAttempt(this.familyContext.getActiveStudentId(), paperId, version);
  }

  statusLabel(item: PracticeAttemptSummary): string {
    return item.status === PracticeAttemptStatus.SUBMITTED ? '已完成' : '进行中';
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

  correctRateText(item: PracticeAttemptSummary): string {
    if (item.status !== PracticeAttemptStatus.SUBMITTED || item.maxScore <= 0) return '';
    return `正确率 ${Math.round(item.correctCount * 100 / item.maxScore)}%`;
  }

  timeText(epochMs: number): string {
    if (epochMs <= 0) return '';
    let date = new Date(epochMs);
    let month = date.getMonth() + 1;
    let day = date.getDate();
    let hour = date.getHours();
    let minute = date.getMinutes();
    return `${this.two(month)}-${this.two(day)} ${this.two(hour)}:${this.two(minute)}`;
  }

  elapsedText(seconds: number): string {
    let safeSeconds = Math.max(0, seconds);
    let minutes = Math.floor(safeSeconds / 60);
    let rest = safeSeconds % 60;
    if (minutes <= 0) return `${rest}秒`;
    if (rest <= 0) return `${minutes}分`;
    return `${minutes}分${rest}秒`;
  }

  private two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
