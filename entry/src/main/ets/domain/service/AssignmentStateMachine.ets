import { AssignmentStatus } from '../model/HomeworkModels';

export class AssignmentStateMachine {
  static canTransition(from: AssignmentStatus, to: AssignmentStatus): boolean {
    if (from === to) return true;

    if (from === AssignmentStatus.NOT_STARTED) {
      if (to === AssignmentStatus.IN_PROGRESS) return true;
      if (to === AssignmentStatus.OVERDUE) return true;
      return false;
    }

    if (from === AssignmentStatus.IN_PROGRESS) {
      if (to === AssignmentStatus.PAUSED) return true;
      if (to === AssignmentStatus.READY_TO_SUBMIT) return true;
      if (to === AssignmentStatus.NOT_STARTED) return true;
      if (to === AssignmentStatus.OVERDUE) return true;
      return false;
    }

    if (from === AssignmentStatus.PAUSED) {
      if (to === AssignmentStatus.IN_PROGRESS) return true;
      if (to === AssignmentStatus.NOT_STARTED) return true;
      if (to === AssignmentStatus.OVERDUE) return true;
      return false;
    }

    if (from === AssignmentStatus.READY_TO_SUBMIT) {
      if (to === AssignmentStatus.SUBMITTED) return true;
      if (to === AssignmentStatus.IN_PROGRESS) return true;
      return false;
    }

    if (from === AssignmentStatus.SUBMITTED) {
      if (to === AssignmentStatus.COMPLETED) return true;
      if (to === AssignmentStatus.NEEDS_REWORK) return true;
      return false;
    }

    if (from === AssignmentStatus.NEEDS_REWORK) {
      if (to === AssignmentStatus.IN_PROGRESS) return true;
      if (to === AssignmentStatus.READY_TO_SUBMIT) return true;
      return false;
    }

    if (from === AssignmentStatus.OVERDUE) {
      if (to === AssignmentStatus.IN_PROGRESS) return true;
      if (to === AssignmentStatus.READY_TO_SUBMIT) return true;
      return false;
    }

    return false;
  }

  static transition(from: AssignmentStatus, to: AssignmentStatus): AssignmentStatus {
    if (!AssignmentStateMachine.canTransition(from, to)) {
      throw new Error(`Illegal assignment transition: ${from} -> ${to}`);
    }
    return to;
  }

  static label(status: AssignmentStatus): string {
    switch (status) {
      case AssignmentStatus.NOT_STARTED:
        return '未开始';
      case AssignmentStatus.IN_PROGRESS:
        return '正在做';
      case AssignmentStatus.PAUSED:
        return '已暂停';
      case AssignmentStatus.READY_TO_SUBMIT:
        return '待提交';
      case AssignmentStatus.SUBMITTED:
        return '已提交';
      case AssignmentStatus.COMPLETED:
        return '已完成';
      case AssignmentStatus.NEEDS_REWORK:
        return '要订正';
      case AssignmentStatus.OVERDUE:
        return '已逾期';
      default:
        return '未知';
    }
  }
}
