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

  static paperKey(paperId: string, version: number): string {
    return `${paperId}@${version}`;
  }

  static passedPaperKeys(attempts: PracticeAttemptSummary[]): string[] {
    let result: string[] = [];
    for (let item of attempts) {
      if (!PracticePassPolicy.isPassedAttempt(item)) continue;
      let key = PracticePassPolicy.paperKey(item.paperId, item.paperVersion);
      let exists = false;
      for (let current of result) {
        if (current === key) {
          exists = true;
          break;
        }
      }
      if (!exists) result.push(key);
    }
    return result;
  }

  static isPaperPassed(paper: PracticePaper, passedPaperKeys: string[]): boolean {
    let key = PracticePassPolicy.paperKey(paper.id, paper.version);
    for (let current of passedPaperKeys) {
      if (current === key) return true;
    }
    return false;
  }
}
