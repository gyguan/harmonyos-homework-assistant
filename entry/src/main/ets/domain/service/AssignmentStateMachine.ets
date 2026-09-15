import { AssignmentStatus } from '../model/HomeworkModels';

export class AssignmentStateMachine {
  static canTransition(from: AssignmentStatus, to: AssignmentStatus): boolean {
    if (from === AssignmentStatus.NOT_STARTED) {
      return to === AssignmentStatus.IN_PROGRESS || to === AssignmentStatus.OVERDUE;
    }
    if (from === AssignmentStatus.IN_PROGRESS) {
      return to === AssignmentStatus.PAUSED || to === AssignmentStatus.READY_TO_SUBMIT || to === AssignmentStatus.OVERDUE;
    }
    if (from === AssignmentStatus.PAUSED) {
      return to === AssignmentStatus.IN_PROGRESS || to === AssignmentStatus.OVERDUE;
    }
    if (from === AssignmentStatus.READY_TO_SUBMIT) {
      return to === AssignmentStatus.SUBMITTED;
    }
    if (from === AssignmentStatus.SUBMITTED) {
      return to === AssignmentStatus.COMPLETED || to === AssignmentStatus.NEEDS_REWORK;
    }
    if (from === AssignmentStatus.NEEDS_REWORK) {
      return to === AssignmentStatus.IN_PROGRESS;
    }
    if (from === AssignmentStatus.OVERDUE) {
      return to === AssignmentStatus.IN_PROGRESS;
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
        return '需要重做';
      case AssignmentStatus.OVERDUE:
        return '已超时';
      default:
        return '未知';
    }
  }
}
