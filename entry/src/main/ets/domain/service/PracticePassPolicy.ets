import {
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticePaper
} from '../model/practice/PracticeModels';

export class PracticePassPolicy {
  static readonly PASS_PERCENT: number = 60;

  static isPassedAttempt(item: PracticeAttemptSummary): boolean {
    if (item.status !== PracticeAttemptStatus.SUBMITTED) return false;
    if (item.mode !== PracticeAttemptMode.FULL) return false;
    if (item.maxScore <= 0) return false;
    return item.score * 100 >= item.maxScore * PracticePassPolicy.PASS_PERCENT;
  }

  static passedPaperIds(attempts: PracticeAttemptSummary[]): string[] {
    let result: string[] = [];
    for (let item of attempts) {
      if (!PracticePassPolicy.isPassedAttempt(item)) continue;
      let exists = false;
      for (let current of result) {
        if (current === item.paperId) {
          exists = true;
          break;
        }
      }
      if (!exists) result.push(item.paperId);
    }
    return result;
  }

  static isPaperPassed(paper: PracticePaper, passedPaperIds: string[]): boolean {
    for (let paperId of passedPaperIds) {
      if (paperId === paper.id) return true;
    }
    return false;
  }
}
