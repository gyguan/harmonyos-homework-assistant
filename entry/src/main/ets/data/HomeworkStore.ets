import { MockData } from './MockData';
import {
  AppSettings,
  Assignment,
  AssignmentProgress,
  AssignmentStatus,
  CandidateAssignment,
  DashboardSummary,
  RawHomeworkImport,
  StudentProfile,
  Submission,
  SubmissionType,
  TodaySummary,
  TutorSession
} from '../domain/model/HomeworkModels';
import { HomeworkSnapshot } from '../domain/model/PersistenceModels';
import { HomeworkPersistence } from '../domain/port/HomeworkPersistence';
import { AssignmentStateMachine } from '../domain/service/AssignmentStateMachine';

const SNAPSHOT_SCHEMA_VERSION: number = 2;

export class HomeworkStore {
  static readonly instance: HomeworkStore = new HomeworkStore();

  private settings: AppSettings = MockData.settings;
  private assignments: Assignment[] = [];
  private candidates: CandidateAssignment[] = [];
  private submissions: Submission[] = [];
  private tutorSessions: TutorSession[] = [];
  private rawImport: RawHomeworkImport = MockData.rawImport;
  private submissionSequence: number = 1;
  private persistence: HomeworkPersistence | null = null;
  private persistRequested: boolean = false;
  private persistRunning: boolean = false;

  private constructor() {
    this.seedFromMockData();
  }

  async initialize(persistence: HomeworkPersistence): Promise<void> {
    this.persistence = persistence;
    let snapshot = await persistence.load();
    if (snapshot !== null && snapshot.schemaVersion === SNAPSHOT_SCHEMA_VERSION) {
      this.restoreSnapshot(snapshot);
      return;
    }
    this.seedFromMockData();
    await persistence.save(this.createSnapshot());
  }

  private seedFromMockData(): void {
    this.settings = this.cloneSettings(MockData.settings);
    this.rawImport = this.cloneRawImport(MockData.rawImport);
    this.assignments = [];
    this.candidates = [];
    this.submissions = [];
    this.tutorSessions = [];
    this.submissionSequence = 1;
    for (let assignment of MockData.assignments) {
      this.assignments.push(this.cloneAssignment(assignment));
    }
    for (let candidate of MockData.candidates) {
      this.candidates.push(this.cloneCandidate(candidate));
    }
  }

  private restoreSnapshot(snapshot: HomeworkSnapshot): void {
    this.settings = this.cloneSettings(snapshot.settings);
    this.assignments = [];
    this.candidates = [];
    this.submissions = [];
    this.tutorSessions = [];
    for (let assignment of snapshot.assignments) {
      this.assignments.push(this.cloneAssignment(assignment));
    }
    for (let candidate of snapshot.candidates) {
      this.candidates.push(this.cloneCandidate(candidate));
    }
    for (let submission of snapshot.submissions) {
      this.submissions.push(this.cloneSubmission(submission));
    }
    for (let session of snapshot.tutorSessions) {
      this.tutorSessions.push(this.cloneTutorSession(session));
    }
    this.submissionSequence = snapshot.submissionSequence > 0 ? snapshot.submissionSequence : 1;
  }

  private createSnapshot(): HomeworkSnapshot {
    let assignmentCopies: Assignment[] = [];
    let candidateCopies: CandidateAssignment[] = [];
    let submissionCopies: Submission[] = [];
    let tutorSessionCopies: TutorSession[] = [];
    for (let assignment of this.assignments) {
      assignmentCopies.push(this.cloneAssignment(assignment));
    }
    for (let candidate of this.candidates) {
      candidateCopies.push(this.cloneCandidate(candidate));
    }
    for (let submission of this.submissions) {
      submissionCopies.push(this.cloneSubmission(submission));
    }
    for (let session of this.tutorSessions) {
      tutorSessionCopies.push(this.cloneTutorSession(session));
    }
    return {
      schemaVersion: SNAPSHOT_SCHEMA_VERSION,
      settings: this.cloneSettings(this.settings),
      assignments: assignmentCopies,
      candidates: candidateCopies,
      submissions: submissionCopies,
      tutorSessions: tutorSessionCopies,
      submissionSequence: this.submissionSequence
    };
  }

  private requestPersist(): void {
    if (this.persistence === null) {
      return;
    }
    this.persistRequested = true;
    if (!this.persistRunning) {
      this.flushPersistQueue();
    }
  }

  private async flushPersistQueue(): Promise<void> {
    let persistence = this.persistence;
    if (persistence === null || this.persistRunning) {
      return;
    }
    this.persistRunning = true;
    while (this.persistRequested) {
      this.persistRequested = false;
      await persistence.save(this.createSnapshot());
    }
    this.persistRunning = false;
  }

  private cloneStudent(source: StudentProfile): StudentProfile {
    return {
      id: source.id,
      name: source.name,
      grade: source.grade,
      semester: source.semester,
      textbookSummary: source.textbookSummary
    };
  }

  private cloneSettings(source: AppSettings): AppSettings {
    return {
      student: this.cloneStudent(source.student),
      tutorGuidanceFirst: source.tutorGuidanceFirst,
      directAnswerAllowed: source.directAnswerAllowed
    };
  }

  private cloneRawImport(source: RawHomeworkImport): RawHomeworkImport {
    return {
      id: source.id,
      sourceKind: source.sourceKind,
      sourceLabel: source.sourceLabel,
      resourceUri: source.resourceUri,
      rawText: source.rawText
    };
  }

  private cloneAssignment(source: Assignment): Assignment {
    return {
      id: source.id,
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

  private cloneSubmission(source: Submission): Submission {
    return {
      id: source.id,
      assignmentId: source.assignmentId,
      type: source.type,
      fileLabel: source.fileLabel,
      submittedAtText: source.submittedAtText
    };
  }

  private cloneTutorSession(source: TutorSession): TutorSession {
    return {
      id: source.id,
      assignmentId: source.assignmentId,
      startedAtText: source.startedAtText,
      questionCount: source.questionCount
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

  private candidateIndex(candidateId: string): number {
    for (let i = 0; i < this.candidates.length; i++) {
      if (this.candidates[i].id === candidateId) {
        return i;
      }
    }
    return -1;
  }

  private hasAssignmentForCandidate(candidateId: string): boolean {
    if (candidateId.length === 0) {
      return false;
    }
    for (let assignment of this.assignments) {
      if (assignment.candidateId === candidateId) {
        return true;
      }
    }
    return false;
  }

  getSettings(): AppSettings {
    return this.settings;
  }

  getStudent(): StudentProfile {
    return this.settings.student;
  }

  getRawImport(): RawHomeworkImport {
    return this.rawImport;
  }

  replaceRawImport(input: RawHomeworkImport): void {
    this.rawImport = this.cloneRawImport(input);
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

  replaceCandidates(candidates: CandidateAssignment[]): void {
    this.candidates = [];
    for (let candidate of candidates) {
      if (!this.hasAssignmentForCandidate(candidate.id)) {
        this.candidates.push(this.cloneCandidate(candidate));
      }
    }
    this.requestPersist();
  }

  updateCandidate(candidate: CandidateAssignment): boolean {
    let index = this.candidateIndex(candidate.id);
    if (index < 0) {
      return false;
    }
    this.candidates[index] = this.cloneCandidate(candidate);
    this.requestPersist();
    return true;
  }

  addCandidate(candidate: CandidateAssignment): boolean {
    if (this.candidateIndex(candidate.id) >= 0 || this.hasAssignmentForCandidate(candidate.id)) {
      return false;
    }
    this.candidates.push(this.cloneCandidate(candidate));
    this.requestPersist();
    return true;
  }

  updateCandidateTitle(candidateId: string, title: string): boolean {
    let index = this.candidateIndex(candidateId);
    if (index < 0) {
      return false;
    }
    this.candidates[index].title = title;
    this.candidates[index].instruction = title;
    this.requestPersist();
    return true;
  }

  removeCandidate(candidateId: string): boolean {
    let index = this.candidateIndex(candidateId);
    if (index < 0) {
      return false;
    }
    this.candidates.splice(index, 1);
    this.requestPersist();
    return true;
  }

  publishCandidates(): number {
    let published: number = 0;
    for (let candidate of this.candidates) {
      if (this.hasAssignmentForCandidate(candidate.id)) {
        continue;
      }
      let assignment: Assignment = {
        id: `a-published-${candidate.id}`,
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
    this.requestPersist();
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
    this.requestPersist();
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
    this.requestPersist();
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
