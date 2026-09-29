import { Assignment, AssignmentStatus } from '../model/HomeworkModels';
import { AssignmentDueDate, DueDateFilterKey } from './AssignmentDueDate';

const NEAR_DUE_WINDOW_MS: number = 60 * 60 * 1000;

export class AssignmentAttentionPolicy {
  static student(assignments: Assignment[], nowEpochMs: number = Date.now()): string {
    let reworkCount = 0;
    let overdueCount = 0;
    let readyCount = 0;
    let nearDue: Assignment | null = null;

    for (let item of assignments) {
      if (item.status === AssignmentStatus.NEEDS_REWORK) {
        reworkCount++;
        continue;
      }
      if (item.status !== AssignmentStatus.SUBMITTED &&
        item.status !== AssignmentStatus.COMPLETED &&
        AssignmentDueDate.matches(item, DueDateFilterKey.OVERDUE, nowEpochMs)) {
        overdueCount++;
        continue;
      }
      if (item.status === AssignmentStatus.READY_TO_SUBMIT) {
        readyCount++;
        continue;
      }
      if (!AssignmentAttentionPolicy.isUnfinished(item.status) || item.dueAtEpochMs <= nowEpochMs) continue;
      if (item.dueAtEpochMs - nowEpochMs > NEAR_DUE_WINDOW_MS) continue;
      if (nearDue === null || item.dueAtEpochMs < nearDue.dueAtEpochMs) nearDue = item;
    }

    if (reworkCount > 0) return reworkCount === 1 ? '有 1 项作业需要订正' : `有 ${reworkCount} 项作业需要订正`;
    if (overdueCount > 0) return overdueCount === 1 ? '有 1 项作业已经逾期' : `有 ${overdueCount} 项作业已经逾期`;
    if (readyCount > 0) return readyCount === 1 ? '有 1 项作业做完了，记得提交' : `有 ${readyCount} 项作业做完了，记得提交`;
    if (nearDue !== null) return `${nearDue.title} 快到截止时间了`;
    return '';
  }

  static parent(assignments: Assignment[], nowEpochMs: number = Date.now()): string {
    let pendingReview = 0;
    let rework = 0;
    let overdue = 0;
    for (let item of assignments) {
      if (item.status === AssignmentStatus.SUBMITTED) pendingReview++;
      else if (item.status === AssignmentStatus.NEEDS_REWORK) rework++;
      else if (item.status !== AssignmentStatus.COMPLETED &&
        AssignmentDueDate.matches(item, DueDateFilterKey.OVERDUE, nowEpochMs)) overdue++;
    }

    if (pendingReview > 0) return pendingReview === 1 ? '有 1 项作业等待验收' : `有 ${pendingReview} 项作业等待验收`;
    if (rework > 0) return rework === 1 ? '有 1 项作业正在订正' : `有 ${rework} 项作业正在订正`;
    if (overdue > 0) return overdue === 1 ? '有 1 项作业已经逾期' : `有 ${overdue} 项作业已经逾期`;
    return '';
  }

  private static isUnfinished(status: AssignmentStatus): boolean {
    return status === AssignmentStatus.NOT_STARTED ||
      status === AssignmentStatus.IN_PROGRESS ||
      status === AssignmentStatus.PAUSED;
  }
}
