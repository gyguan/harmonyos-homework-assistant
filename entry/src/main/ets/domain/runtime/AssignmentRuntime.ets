import { Assignment, AssignmentStatus } from '../model/HomeworkModels';
import { AssignmentCapability, DEFAULT_ASSIGNMENT_CAPABILITY } from '../model/AssignmentCapability';

export interface AssignmentRuntimeSnapshot {
  assignmentId: string;
  status: AssignmentStatus;
  capability: AssignmentCapability;
}

export interface AssignmentRuntime {
  snapshot(): AssignmentRuntimeSnapshot;
  start(): void;
  pause(): void;
  resume(): void;
}

export class DefaultAssignmentRuntime implements AssignmentRuntime {
  private assignment: Assignment;
  private capability: AssignmentCapability;

  constructor(assignment: Assignment, capability: AssignmentCapability = DEFAULT_ASSIGNMENT_CAPABILITY) {
    this.assignment = assignment;
    this.capability = capability;
  }

  snapshot(): AssignmentRuntimeSnapshot {
    return {
      assignmentId: this.assignment.id,
      status: this.assignment.status,
      capability: this.capability
    };
  }

  start(): void {
    if (this.assignment.status === AssignmentStatus.NOT_STARTED ||
      this.assignment.status === AssignmentStatus.PAUSED) {
      this.assignment.status = AssignmentStatus.IN_PROGRESS;
    }
  }

  pause(): void {
    if (this.assignment.status === AssignmentStatus.IN_PROGRESS) {
      this.assignment.status = AssignmentStatus.PAUSED;
    }
  }

  resume(): void {
    this.start();
  }
}
