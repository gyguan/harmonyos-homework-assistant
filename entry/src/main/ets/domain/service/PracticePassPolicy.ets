import {
  PracticeAttemptMode,
  PracticeAttemptStatus,
  PracticeAttemptSummary,
  PracticePaper,
  PracticePassFilter
} from '../model/practice/PracticeModels';

export class PracticePassPolicy {
  static isPassedAttempt(item: PracticeAttemptSummary): boolean {
    if (item.status !== PracticeAttemptStatus.SUBMITTED) return false;
    if (item.mode !== PracticeAttemptMode.FULL) return false;
    if (item.questionCount > 0) return item.correctCount === item.questionCount;
    if (item.maxScore > 0) return item.score === item.maxScore;
    return false;
  }

  static matchesAttemptPassFilter(item: PracticeAttemptSummary, filter: PracticePassFilter): boolean {
    if (filter === PracticePassFilter.ALL) return true;
    if (item.status !== PracticeAttemptStatus.SUBMITTED) return false;
    if (item.mode !== PracticeAttemptMode.FULL) return false;
    let passed = PracticePassPolicy.isPassedAttempt(item);
    if (filter === PracticePassFilter.PASSED) return passed;
    return !passed;
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
