import { Assignment, AssignmentStatus } from '../model/HomeworkModels';
import { AssignmentTaskDate } from './AssignmentTaskDate';

export enum AssignmentAttentionKind {
  NONE = 'NONE',
  STUDENT_REWORK = 'STUDENT_REWORK',
  STUDENT_OVERDUE = 'STUDENT_OVERDUE',
  STUDENT_READY_TO_SUBMIT = 'STUDENT_READY_TO_SUBMIT',
  PARENT_PENDING_REVIEW = 'PARENT_PENDING_REVIEW',
  PARENT_REWORK = 'PARENT_REWORK',
  PARENT_OVERDUE = 'PARENT_OVERDUE'
}

export interface AssignmentAttentionResult {
  kind: AssignmentAttentionKind;
  text: string;
}

export class AssignmentAttentionPolicy {
  static student(assignments: Assignment[], nowEpochMs: number = Date.now()): string {
    return AssignmentAttentionPolicy.studentResult(assignments, nowEpochMs).text;
  }

  static studentResult(assignments: Assignment[],
    nowEpochMs: number = Date.now()): AssignmentAttentionResult {
    let reworkCount = 0;
    let historicalCount = 0;
    let readyCount = 0;
    let today = AssignmentTaskDate.today(nowEpochMs);

    for (let item of assignments) {
      if (item.status === AssignmentStatus.NEEDS_REWORK) {
        reworkCount++;
        continue;
      }
      if (AssignmentAttentionPolicy.isHistoricalUnfinished(item, today)) {
        historicalCount++;
        continue;
      }
      if (item.status === AssignmentStatus.READY_TO_SUBMIT) readyCount++;
    }

    if (reworkCount > 0) {
      return {
        kind: AssignmentAttentionKind.STUDENT_REWORK,
        text: reworkCount === 1 ? '有 1 项作业需要订正' : `有 ${reworkCount} 项作业需要订正`
      };
    }
    if (historicalCount > 0) {
      return {
        kind: AssignmentAttentionKind.STUDENT_OVERDUE,
        text: historicalCount === 1 ? '有 1 项历史任务未完成' : `有 ${historicalCount} 项历史任务未完成`
      };
    }
    if (readyCount > 0) {
      return {
        kind: AssignmentAttentionKind.STUDENT_READY_TO_SUBMIT,
        text: readyCount === 1 ? '有 1 项作业做完了，记得提交' : `有 ${readyCount} 项作业做完了，记得提交`
      };
    }
    return { kind: AssignmentAttentionKind.NONE, text: '' };
  }

  static parent(assignments: Assignment[], nowEpochMs: number = Date.now()): string {
    return AssignmentAttentionPolicy.parentResult(assignments, nowEpochMs).text;
  }

  static parentResult(assignments: Assignment[],
    nowEpochMs: number = Date.now()): AssignmentAttentionResult {
    let pendingReview = 0;
    let rework = 0;
    let historical = 0;
    let today = AssignmentTaskDate.today(nowEpochMs);
    for (let item of assignments) {
      if (item.status === AssignmentStatus.SUBMITTED) pendingReview++;
      else if (item.status === AssignmentStatus.NEEDS_REWORK) rework++;
      else if (AssignmentAttentionPolicy.isHistoricalUnfinished(item, today)) historical++;
    }

    if (pendingReview > 0) {
      return {
        kind: AssignmentAttentionKind.PARENT_PENDING_REVIEW,
        text: pendingReview === 1 ? '有 1 项作业等待验收' : `有 ${pendingReview} 项作业等待验收`
      };
    }
    if (rework > 0) {
      return {
        kind: AssignmentAttentionKind.PARENT_REWORK,
        text: rework === 1 ? '有 1 项作业正在订正' : `有 ${rework} 项作业正在订正`
      };
    }
    if (historical > 0) {
      return {
        kind: AssignmentAttentionKind.PARENT_OVERDUE,
        text: historical === 1 ? '有 1 项历史任务未完成' : `有 ${historical} 项历史任务未完成`
      };
    }
    return { kind: AssignmentAttentionKind.NONE, text: '' };
  }

  static filter(assignments: Assignment[], kind: AssignmentAttentionKind,
    nowEpochMs: number = Date.now()): Assignment[] {
    if (kind === AssignmentAttentionKind.NONE) return assignments.slice();
    let result: Assignment[] = [];
    for (let item of assignments) {
      if (AssignmentAttentionPolicy.matches(item, kind, nowEpochMs)) result.push(item);
    }
    return result;
  }

  static matches(item: Assignment, kind: AssignmentAttentionKind,
    nowEpochMs: number = Date.now()): boolean {
    if (kind === AssignmentAttentionKind.STUDENT_REWORK ||
      kind === AssignmentAttentionKind.PARENT_REWORK) {
      return item.status === AssignmentStatus.NEEDS_REWORK;
    }
    if (kind === AssignmentAttentionKind.PARENT_PENDING_REVIEW) {
      return item.status === AssignmentStatus.SUBMITTED;
    }
    if (kind === AssignmentAttentionKind.STUDENT_READY_TO_SUBMIT) {
      return item.status === AssignmentStatus.READY_TO_SUBMIT;
    }
    if (kind === AssignmentAttentionKind.STUDENT_OVERDUE ||
      kind === AssignmentAttentionKind.PARENT_OVERDUE) {
      return AssignmentAttentionPolicy.isHistoricalUnfinished(
        item, AssignmentTaskDate.today(nowEpochMs));
    }
    return false;
  }

  static label(kind: AssignmentAttentionKind): string {
    if (kind === AssignmentAttentionKind.STUDENT_REWORK) return '待订正';
    if (kind === AssignmentAttentionKind.STUDENT_OVERDUE) return '历史未完成';
    if (kind === AssignmentAttentionKind.STUDENT_READY_TO_SUBMIT) return '待提交';
    if (kind === AssignmentAttentionKind.PARENT_PENDING_REVIEW) return '待验收';
    if (kind === AssignmentAttentionKind.PARENT_REWORK) return '正在订正';
    if (kind === AssignmentAttentionKind.PARENT_OVERDUE) return '历史未完成';
    return '';
  }

  private static isHistoricalUnfinished(item: Assignment, today: string): boolean {
    if (item.taskDate >= today) return false;
    return item.status !== AssignmentStatus.SUBMITTED &&
      item.status !== AssignmentStatus.COMPLETED &&
      item.status !== AssignmentStatus.NEEDS_REWORK;
  }
}
