import { DefaultFamilyContextRepository } from '../../../data/repository/DefaultFamilyContextRepository';
import { DefaultPracticeRepository } from '../../../data/repository/DefaultPracticeRepository';
import { PracticeAttemptMode, PracticeAttemptSummary, PracticeAttemptStatus } from '../../../domain/model/practice/PracticeModels';
import { FamilyContextRepository } from '../../../domain/port/FamilyContextRepository';
import { PracticeRepository } from '../../../domain/port/PracticeRepository';

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

  list(): Promise<PracticeAttemptSummary[]> {
    return this.repository.listAttempts(this.familyContext.getActiveStudentId(), '');
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
    if (seconds <= 0) return '未完成';
    let minutes = Math.floor(seconds / 60);
    let rest = seconds % 60;
    return `${minutes}分${rest}秒`;
  }

  private two(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }
}
