import { MockData } from './MockData';
import {
  Assignment,
  AssignmentProgress,
  AssignmentStatus,
  CandidateAssignment,
  DashboardSummary,
  RawHomeworkImport,
  Submission,
  SubmissionType,
  TodaySummary
} from '../domain/model/HomeworkModels';
import { AssignmentStateMachine } from '../domain/service/AssignmentStateMachine';

export class HomeworkStore {
  static readonly instance: HomeworkStore = new HomeworkStore();

  private assignments: Assignment[] = [];
  private candidates: CandidateAssignment[] = [];
  private submissions: Submission[] = [];
  private readonly rawImport: RawHomeworkImport = MockData.rawImport;
  private submissionSequence: number = 1;

  private constructor() {
    for (let assignment of MockData.assignments) {
      this.assignments.push(this.cloneAssignment(assignment));
    }
    for (let candidate of MockData.candidates) {
      this.candidates.push(this.cloneCandidate(candidate));
    }
  }

  private cloneAssignment(source: Assignment): Assignment {
    return {
      id: source.id,
      familyId: source.familyId,
      studentId: source.studentId,
      candidateId: source.candidateId,
      subject: source.subject,
      title: source.title,
      instruction: source.instruction,
      textbookRef: source.textbookRef,
      dueText: source.dueText,
      status: source.status,
      resourceLabels: source.resourceLabels.slice()
    };
  }

  private cloneCandidate(source: CandidateAssignment): CandidateAssignment {
    return {
      id: source.id,
      familyId: source.familyId,
      studentId: source.studentId,
      subject: source.subject,
      title: source.title,
      instruction: source.instruction,
      textbookRef: source.textbookRef,
      dueText: source.dueText,
      sourceEvidence: {
        sourceLabel: source.sourceEvidence.sourceLabel,
        excerpt: source.sourceEvidence.excerpt
      },
      confidence: source.confidence
    };
  }

  private assignmentIndex(assignmentId: string): number {
    for (let i = 0; i < this.assignments.length; i++) {
      if (this.assignments[i].id === assignmentId) {
        return i;
      }
    }
    return -1;
  }

  getRawImport(): RawHomeworkImport {
    return this.rawImport;
  }

  getAssignments(): Assignment[] {
    return this.assignments;
  }

  getTodayAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let assignment of this.assignments) {
      if (assignment.status !== AssignmentStatus.OVERDUE) {
        result.push(assignment);
      }
    }
    return result;
  }

  getAssignment(assignmentId: string): Assignment | null {
    let index = this.assignmentIndex(assignmentId);
    if (index < 0) {
      return null;
    }
    return this.assignments[index];
  }

  getNextAssignment(): Assignment | null {
    let priorities: AssignmentStatus[] = [
      AssignmentStatus.IN_PROGRESS,
      AssignmentStatus.NEEDS_REWORK,
      AssignmentStatus.NOT_STARTED,
      AssignmentStatus.OVERDUE,
      AssignmentStatus.READY_TO_SUBMIT
    ];
    for (let status of priorities) {
      for (let assignment of this.assignments) {
        if (assignment.status === status) {
          return assignment;
        }
      }
    }
    return null;
  }

  getCandidates(): CandidateAssignment[] {
    return this.candidates;
  }

  updateCandidateTitle(candidateId: string, title: string): boolean {
    for (let candidate of this.candidates) {
      if (candidate.id === candidateId) {
        candidate.title = title;
        return true;
      }
    }
    return false;
  }

  removeCandidate(candidateId: string): boolean {
    for (let i = 0; i < this.candidates.length; i++) {
      if (this.candidates[i].id === candidateId) {
        this.candidates.splice(i, 1);
        return true;
      }
    }
    return false;
  }

  publishCandidates(): number {
    let published: number = 0;
    for (let candidate of this.candidates) {
      let assignment: Assignment = {
        id: `a-published-${candidate.id}`,
        familyId: candidate.familyId,
        studentId: candidate.studentId,
        candidateId: candidate.id,
        subject: candidate.subject,
        title: candidate.title,
        instruction: candidate.instruction,
        textbookRef: candidate.textbookRef,
        dueText: candidate.dueText,
        status: AssignmentStatus.NOT_STARTED,
        resourceLabels: []
      };
      this.assignments.push(assignment);
      published++;
    }
    this.candidates = [];
    return published;
  }

  transitionAssignment(assignmentId: string, to: AssignmentStatus): boolean {
    let index = this.assignmentIndex(assignmentId);
    if (index < 0) {
      return false;
    }
    let current = this.assignments[index].status;
    if (!AssignmentStateMachine.canTransition(current, to)) {
      return false;
    }
    this.assignments[index].status = AssignmentStateMachine.transition(current, to);
    return true;
  }

  startAssignment(assignmentId: string): boolean {
    let assignment = this.getAssignment(assignmentId);
    if (assignment === null) {
      return false;
    }
    if (assignment.status === AssignmentStatus.IN_PROGRESS ||
      assignment.status === AssignmentStatus.READY_TO_SUBMIT ||
      assignment.status === AssignmentStatus.SUBMITTED) {
      return true;
    }
    return this.transitionAssignment(assignmentId, AssignmentStatus.IN_PROGRESS);
  }

  markReadyToSubmit(assignmentId: string): boolean {
    return this.transitionAssignment(assignmentId, AssignmentStatus.READY_TO_SUBMIT);
  }

  submitMockImage(assignmentId: string): boolean {
    if (!this.transitionAssignment(assignmentId, AssignmentStatus.SUBMITTED)) {
      return false;
    }
    let submission: Submission = {
      id: `submission-${this.submissionSequence}`,
      assignmentId: assignmentId,
      type: SubmissionType.MOCK_IMAGE,
      fileLabel: '作业照片 1 张（Mock）',
      submittedAtText: '刚刚'
    };
    this.submissionSequence++;
    this.submissions.push(submission);
    return true;
  }

  getSubmissionsForAssignment(assignmentId: string): Submission[] {
    let result: Submission[] = [];
    for (let submission of this.submissions) {
      if (submission.assignmentId === assignmentId) {
        result.push(submission);
      }
    }
    return result;
  }

  getTodaySummary(): TodaySummary {
    let today = this.getTodayAssignments();
    let completed: number = 0;
    for (let assignment of today) {
      if (assignment.status === AssignmentStatus.COMPLETED) {
        completed++;
      }
    }
    let next = this.getNextAssignment();
    return {
      completed: completed,
      total: today.length,
      nextAssignmentId: next === null ? '' : next.id
    };
  }

  getDashboardSummary(): DashboardSummary {
    let summary: DashboardSummary = {
      completed: 0,
      inProgress: 0,
      notStarted: 0,
      overdue: 0,
      readyToSubmit: 0,
      submitted: 0,
      needsRework: 0
    };
    for (let assignment of this.assignments) {
      switch (assignment.status) {
        case AssignmentStatus.COMPLETED:
          summary.completed++;
          break;
        case AssignmentStatus.IN_PROGRESS:
          summary.inProgress++;
          break;
        case AssignmentStatus.NOT_STARTED:
          summary.notStarted++;
          break;
        case AssignmentStatus.OVERDUE:
          summary.overdue++;
          break;
        case AssignmentStatus.READY_TO_SUBMIT:
          summary.readyToSubmit++;
          break;
        case AssignmentStatus.SUBMITTED:
          summary.submitted++;
          break;
        case AssignmentStatus.NEEDS_REWORK:
          summary.needsRework++;
          break;
      }
    }
    return summary;
  }

  getProgress(): AssignmentProgress[] {
    let result: AssignmentProgress[] = [];
    for (let assignment of this.assignments) {
      result.push({
        assignmentId: assignment.id,
        status: assignment.status,
        statusLabel: AssignmentStateMachine.label(assignment.status),
        submissionCount: this.getSubmissionsForAssignment(assignment.id).length
      });
    }
    return result;
  }
}
