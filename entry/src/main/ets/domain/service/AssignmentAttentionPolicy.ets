import { Assignment, AssignmentStatus } from '../model/HomeworkModels';
import { AssignmentDueDate, DueDateFilterKey } from './AssignmentDueDate';

const NEAR_DUE_WINDOW_MS: number = 60 * 60 * 1000;

export enum AssignmentAttentionKind {
  NONE = 'NONE',
  STUDENT_REWORK = 'STUDENT_REWORK',
  STUDENT_OVERDUE = 'STUDENT_OVERDUE',
  STUDENT_READY_TO_SUBMIT = 'STUDENT_READY_TO_SUBMIT',
  STUDENT_NEAR_DUE = 'STUDENT_NEAR_DUE',
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

  static studentResult(
    assignments: Assignment[],
    nowEpochMs: number = Date.now()
  ): AssignmentAttentionResult {
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

    if (reworkCount > 0) {
      return {
        kind: AssignmentAttentionKind.STUDENT_REWORK,
        text: reworkCount === 1 ? '有 1 项作业需要订正' : `有 ${reworkCount} 项作业需要订正`
      };
    }
    if (overdueCount > 0) {
      return {
        kind: AssignmentAttentionKind.STUDENT_OVERDUE,
        text: overdueCount === 1 ? '有 1 项作业已经逾期' : `有 ${overdueCount} 项作业已经逾期`
      };
    }
    if (readyCount > 0) {
      return {
        kind: AssignmentAttentionKind.STUDENT_READY_TO_SUBMIT,
        text: readyCount === 1 ? '有 1 项作业做完了，记得提交' : `有 ${readyCount} 项作业做完了，记得提交`
      };
    }
    if (nearDue !== null) {
      return {
        kind: AssignmentAttentionKind.STUDENT_NEAR_DUE,
        text: `${nearDue.title} 快到截止时间了`
      };
    }
    return { kind: AssignmentAttentionKind.NONE, text: '' };
  }

  static parent(assignments: Assignment[], nowEpochMs: number = Date.now()): string {
    return AssignmentAttentionPolicy.parentResult(assignments, nowEpochMs).text;
  }

  static parentResult(
    assignments: Assignment[],
    nowEpochMs: number = Date.now()
  ): AssignmentAttentionResult {
    let pendingReview = 0;
    let rework = 0;
    let overdue = 0;
    for (let item of assignments) {
      if (item.status === AssignmentStatus.SUBMITTED) pendingReview++;
      else if (item.status === AssignmentStatus.NEEDS_REWORK) rework++;
      else if (item.status !== AssignmentStatus.COMPLETED &&
        AssignmentDueDate.matches(item, DueDateFilterKey.OVERDUE, nowEpochMs)) overdue++;
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
    if (overdue > 0) {
      return {
        kind: AssignmentAttentionKind.PARENT_OVERDUE,
        text: overdue === 1 ? '有 1 项作业已经逾期' : `有 ${overdue} 项作业已经逾期`
      };
    }
    return { kind: AssignmentAttentionKind.NONE, text: '' };
  }

  static filter(
    assignments: Assignment[],
    kind: AssignmentAttentionKind,
    nowEpochMs: number = Date.now()
  ): Assignment[] {
    if (kind === AssignmentAttentionKind.NONE) return assignments.slice();
    let result: Assignment[] = [];
    for (let item of assignments) {
      if (AssignmentAttentionPolicy.matches(item, kind, nowEpochMs)) result.push(item);
    }
    return result;
  }

  static matches(
    item: Assignment,
    kind: AssignmentAttentionKind,
    nowEpochMs: number = Date.now()
  ): boolean {
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
    if (kind === AssignmentAttentionKind.STUDENT_NEAR_DUE) {
      if (!AssignmentAttentionPolicy.isUnfinished(item.status)) return false;
      if (item.dueAtEpochMs <= nowEpochMs) return false;
      return item.dueAtEpochMs - nowEpochMs <= NEAR_DUE_WINDOW_MS;
    }
    if (kind === AssignmentAttentionKind.STUDENT_OVERDUE) {
      if (item.status === AssignmentStatus.SUBMITTED ||
        item.status === AssignmentStatus.COMPLETED ||
        item.status === AssignmentStatus.NEEDS_REWORK) return false;
      return AssignmentDueDate.matches(item, DueDateFilterKey.OVERDUE, nowEpochMs);
    }
    if (kind === AssignmentAttentionKind.PARENT_OVERDUE) {
      if (item.status === AssignmentStatus.SUBMITTED ||
        item.status === AssignmentStatus.COMPLETED ||
        item.status === AssignmentStatus.NEEDS_REWORK) return false;
      return AssignmentDueDate.matches(item, DueDateFilterKey.OVERDUE, nowEpochMs);
    }
    return false;
  }

  static label(kind: AssignmentAttentionKind): string {
    if (kind === AssignmentAttentionKind.STUDENT_REWORK) return '待订正';
    if (kind === AssignmentAttentionKind.STUDENT_OVERDUE) return '已逾期';
    if (kind === AssignmentAttentionKind.STUDENT_READY_TO_SUBMIT) return '待提交';
    if (kind === AssignmentAttentionKind.STUDENT_NEAR_DUE) return '临近截止';
    if (kind === AssignmentAttentionKind.PARENT_PENDING_REVIEW) return '待验收';
    if (kind === AssignmentAttentionKind.PARENT_REWORK) return '正在订正';
    if (kind === AssignmentAttentionKind.PARENT_OVERDUE) return '已逾期';
    return '';
  }

  private static isUnfinished(status: AssignmentStatus): boolean {
    return status === AssignmentStatus.NOT_STARTED ||
      status === AssignmentStatus.IN_PROGRESS ||
      status === AssignmentStatus.PAUSED;
  }
}
