import { MockData } from './MockData';
import {
  AppSettings,
  Assignment,
  AssignmentContentType,
  AssignmentProgress,
  AssignmentStatus,
  AssignmentType,
  CandidateAssignment,
  DashboardSummary,
  HomeworkImportSourceKind,
  RawHomeworkImport,
  Subject,
  StudentProfile,
  Submission,
  SubmissionType,
  TodaySummary,
  TutorSession
} from '../domain/model/HomeworkModels';
import { HomeworkSnapshot } from '../domain/model/PersistenceModels';
import { HomeworkPersistence } from '../domain/port/HomeworkPersistence';
import { AssignmentStateMachine } from '../domain/service/AssignmentStateMachine';
import {
  HOMEWORK_SNAPSHOT_SCHEMA_VERSION,
  HomeworkSnapshotMigrator
} from '../domain/service/HomeworkSnapshotMigrator';

export class HomeworkStore {
  static readonly instance: HomeworkStore = new HomeworkStore();

  private settings: AppSettings = MockData.settings;
  private rawImports: RawHomeworkImport[] = [];
  private assignments: Assignment[] = [];
  private candidates: CandidateAssignment[] = [];
  private submissions: Submission[] = [];
  private tutorSessions: TutorSession[] = [];
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
    if (snapshot === null) {
      this.seedFromMockData();
      await persistence.save(this.createSnapshot());
      return;
    }

    let originalVersion = snapshot.schemaVersion;
    let migrated = HomeworkSnapshotMigrator.migrate(snapshot);
    this.restoreSnapshot(migrated);
    if (originalVersion !== migrated.schemaVersion) {
      await persistence.save(this.createSnapshot());
    }
  }

  private seedFromMockData(): void {
    this.settings = this.cloneSettings(MockData.settings);
    this.rawImports = [];
    this.assignments = [];
    this.candidates = [];
    this.submissions = [];
    this.tutorSessions = [];
    this.submissionSequence = 1;
    for (let rawImport of MockData.rawImports) this.rawImports.push(this.cloneRawImport(rawImport));
    for (let assignment of MockData.assignments) this.assignments.push(this.cloneAssignment(assignment));
    for (let candidate of MockData.candidates) this.candidates.push(this.cloneCandidate(candidate));
  }

  private restoreSnapshot(snapshot: HomeworkSnapshot): void {
    this.settings = this.cloneSettings(snapshot.settings);
    this.rawImports = [];
    this.assignments = [];
    this.candidates = [];
    this.submissions = [];
    this.tutorSessions = [];
    for (let rawImport of snapshot.rawImports) this.rawImports.push(this.cloneRawImport(rawImport));
    for (let assignment of snapshot.assignments) this.assignments.push(this.cloneAssignment(assignment));
    for (let candidate of snapshot.candidates) this.candidates.push(this.cloneCandidate(candidate));
    for (let submission of snapshot.submissions) this.submissions.push(this.cloneSubmission(submission));
    for (let session of snapshot.tutorSessions) this.tutorSessions.push(this.cloneTutorSession(session));
    this.submissionSequence = snapshot.submissionSequence > 0 ? snapshot.submissionSequence : 1;
    if (this.studentIndex(this.settings.activeStudentId) < 0 && this.settings.students.length > 0) {
      this.settings.activeStudentId = this.settings.students[0].id;
    }
  }

  private createSnapshot(): HomeworkSnapshot {
    let rawImportCopies: RawHomeworkImport[] = [];
    let assignmentCopies: Assignment[] = [];
    let candidateCopies: CandidateAssignment[] = [];
    let submissionCopies: Submission[] = [];
    let tutorSessionCopies: TutorSession[] = [];
    for (let rawImport of this.rawImports) rawImportCopies.push(this.cloneRawImport(rawImport));
    for (let assignment of this.assignments) assignmentCopies.push(this.cloneAssignment(assignment));
    for (let candidate of this.candidates) candidateCopies.push(this.cloneCandidate(candidate));
    for (let submission of this.submissions) submissionCopies.push(this.cloneSubmission(submission));
    for (let session of this.tutorSessions) tutorSessionCopies.push(this.cloneTutorSession(session));
    return {
      schemaVersion: HOMEWORK_SNAPSHOT_SCHEMA_VERSION,
      settings: this.cloneSettings(this.settings),
      rawImports: rawImportCopies,
      assignments: assignmentCopies,
      candidates: candidateCopies,
      submissions: submissionCopies,
      tutorSessions: tutorSessionCopies,
      submissionSequence: this.submissionSequence
    };
  }

  private requestPersist(): void {
    if (this.persistence === null) return;
    this.persistRequested = true;
    if (!this.persistRunning) this.flushPersistQueue();
  }

  private async flushPersistQueue(): Promise<void> {
    let persistence = this.persistence;
    if (persistence === null || this.persistRunning) return;
    this.persistRunning = true;
    while (this.persistRequested) {
      this.persistRequested = false;
      await persistence.save(this.createSnapshot());
    }
    this.persistRunning = false;
  }

  private cloneStudent(source: StudentProfile): StudentProfile {
    return { id: source.id, name: source.name, grade: source.grade, className: source.className,
      semester: source.semester, textbookSummary: source.textbookSummary };
  }

  private cloneSettings(source: AppSettings): AppSettings {
    let students: StudentProfile[] = [];
    for (let student of source.students) students.push(this.cloneStudent(student));
    return { students: students, activeStudentId: source.activeStudentId,
      tutorGuidanceFirst: source.tutorGuidanceFirst, directAnswerAllowed: source.directAnswerAllowed };
  }

  private cloneRawImport(source: RawHomeworkImport): RawHomeworkImport {
    return { id: source.id, studentId: source.studentId, sourceKind: source.sourceKind,
      sourceLabel: source.sourceLabel, resourceUri: source.resourceUri, rawText: source.rawText };
  }

  private cloneAssignment(source: Assignment): Assignment {
    return {
      id: source.id,
      studentId: source.studentId,
      candidateId: source.candidateId,
      assignmentType: source.assignmentType,
      subjectCode: source.subjectCode,
      contentType: source.contentType === AssignmentContentType.AUDIO_IMAGE ?
        AssignmentContentType.AUDIO_IMAGE : AssignmentContentType.NORMAL,
      subject: source.subject,
      title: source.title,
      instruction: source.instruction,
      textbookRef: source.textbookRef,
      dueAtEpochMs: source.dueAtEpochMs > 0 ? source.dueAtEpochMs : 0,
      dueTimezone: source.dueTimezone.length > 0 ? source.dueTimezone : 'Asia/Shanghai',
      dueText: source.dueText,
      dueDateKey: source.dueDateKey,
      status: source.status,
      expectedMinutes: source.expectedMinutes > 0 ? source.expectedMinutes : 20,
      startedAtEpochMs: source.startedAtEpochMs > 0 ? source.startedAtEpochMs : 0,
      finishedAtEpochMs: source.finishedAtEpochMs > 0 ? source.finishedAtEpochMs : 0,
      elapsedSeconds: source.elapsedSeconds > 0 ? source.elapsedSeconds : 0,
      reviewNote: source.reviewNote === undefined ? '' : source.reviewNote,
      remoteVersion: source.remoteVersion > 0 ? source.remoteVersion : 0,
      syncDirty: source.syncDirty === true,
      lastSyncedAtEpochMs: source.lastSyncedAtEpochMs > 0 ? source.lastSyncedAtEpochMs : 0,
      resourceLabels: source.resourceLabels.slice()
    };
  }

  private cloneCandidate(source: CandidateAssignment): CandidateAssignment {
    return { id: source.id, studentId: source.studentId, subject: source.subject, title: source.title,
      instruction: source.instruction, textbookRef: source.textbookRef, dueText: source.dueText,
      expectedMinutes: source.expectedMinutes > 0 ? source.expectedMinutes : 20,
      sourceEvidence: { sourceLabel: source.sourceEvidence.sourceLabel, excerpt: source.sourceEvidence.excerpt },
      confidence: source.confidence };
  }

  private cloneSubmission(source: Submission): Submission {
    return { id: source.id, assignmentId: source.assignmentId, type: source.type,
      photoUris: source.photoUris.slice(), fileLabel: source.fileLabel, submittedAtText: source.submittedAtText };
  }

  private cloneTutorSession(source: TutorSession): TutorSession {
    return { id: source.id, studentId: source.studentId, assignmentId: source.assignmentId,
      startedAtText: source.startedAtText, questionCount: source.questionCount };
  }

  private subjectCode(subject: Subject): string {
    if (subject === Subject.CHINESE) return 'CHINESE';
    if (subject === Subject.MATH) return 'MATH';
    if (subject === Subject.ENGLISH) return 'ENGLISH';
    return 'OTHER';
  }

  private studentIndex(studentId: string): number {
    for (let i = 0; i < this.settings.students.length; i++) if (this.settings.students[i].id === studentId) return i;
    return -1;
  }

  private rawImportIndex(studentId: string): number {
    for (let i = 0; i < this.rawImports.length; i++) if (this.rawImports[i].studentId === studentId) return i;
    return -1;
  }

  private assignmentIndex(assignmentId: string): number {
    for (let i = 0; i < this.assignments.length; i++) if (this.assignments[i].id === assignmentId) return i;
    return -1;
  }

  private candidateIndex(candidateId: string): number {
    for (let i = 0; i < this.candidates.length; i++) if (this.candidates[i].id === candidateId) return i;
    return -1;
  }

  private hasAssignmentForCandidate(candidateId: string): boolean {
    if (candidateId.length === 0) return false;
    for (let assignment of this.assignments) if (assignment.candidateId === candidateId) return true;
    return false;
  }

  getSettings(): AppSettings { return this.settings; }

  updateTutorSettings(tutorGuidanceFirst: boolean, directAnswerAllowed: boolean): void {
    this.settings.tutorGuidanceFirst = tutorGuidanceFirst;
    this.settings.directAnswerAllowed = directAnswerAllowed;
    this.requestPersist();
  }

  replaceStudents(students: StudentProfile[]): void {
    let activeStudentId = this.settings.activeStudentId;
    let next: StudentProfile[] = [];
    for (let student of students) next.push(this.cloneStudent(student));
    this.settings.students = next;
    if (this.studentIndex(activeStudentId) >= 0) this.settings.activeStudentId = activeStudentId;
    else if (this.settings.students.length > 0) this.settings.activeStudentId = this.settings.students[0].id;
    this.requestPersist();
  }

  getStudents(): StudentProfile[] { return this.settings.students; }
  getActiveStudentId(): string { return this.settings.activeStudentId; }

  getStudent(): StudentProfile {
    let index = this.studentIndex(this.settings.activeStudentId);
    return index >= 0 ? this.settings.students[index] : this.settings.students[0];
  }

  setActiveStudent(studentId: string): boolean {
    if (studentId === this.settings.activeStudentId) return true;
    if (this.studentIndex(studentId) < 0) return false;
    this.settings.activeStudentId = studentId;
    this.requestPersist();
    return true;
  }

  getRawImport(): RawHomeworkImport {
    let studentId = this.getActiveStudentId();
    let index = this.rawImportIndex(studentId);
    if (index >= 0) return this.rawImports[index];
    return { id: '', studentId: studentId, sourceKind: HomeworkImportSourceKind.TEXT,
      sourceLabel: '', resourceUri: '', rawText: '' };
  }

  replaceRawImport(input: RawHomeworkImport): void {
    if (input.studentId !== this.getActiveStudentId()) return;
    let index = this.rawImportIndex(input.studentId);
    if (index >= 0) this.rawImports[index] = this.cloneRawImport(input);
    else this.rawImports.push(this.cloneRawImport(input));
    this.requestPersist();
  }

  getAssignments(): Assignment[] {
    let result: Assignment[] = [];
    let studentId = this.getActiveStudentId();
    for (let assignment of this.assignments) if (assignment.studentId === studentId) result.push(assignment);
    return result;
  }

  replaceAssignmentsForActiveStudent(assignments: Assignment[]): void {
    let studentId = this.getActiveStudentId();
    let next: Assignment[] = [];
    for (let existing of this.assignments) if (existing.studentId !== studentId) next.push(this.cloneAssignment(existing));
    for (let assignment of assignments) if (assignment.studentId === studentId) next.push(this.cloneAssignment(assignment));
    this.assignments = next;
    this.requestPersist();
  }

  getTodayAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let assignment of this.getAssignments()) if (assignment.status !== AssignmentStatus.OVERDUE) result.push(assignment);
    return result;
  }

  getAssignment(assignmentId: string): Assignment | null {
    let index = this.assignmentIndex(assignmentId);
    if (index < 0 || this.assignments[index].studentId !== this.getActiveStudentId()) return null;
    return this.assignments[index];
  }

  getNextAssignment(): Assignment | null {
    let priorities: AssignmentStatus[] = [AssignmentStatus.IN_PROGRESS, AssignmentStatus.PAUSED,
      AssignmentStatus.NEEDS_REWORK, AssignmentStatus.OVERDUE, AssignmentStatus.NOT_STARTED,
      AssignmentStatus.READY_TO_SUBMIT];
    let activeAssignments = this.getAssignments();
    for (let status of priorities) for (let assignment of activeAssignments) if (assignment.status === status) return assignment;
    return null;
  }

  getCandidates(): CandidateAssignment[] {
    let result: CandidateAssignment[] = [];
    let studentId = this.getActiveStudentId();
    for (let candidate of this.candidates) if (candidate.studentId === studentId) result.push(candidate);
    return result;
  }

  replaceCandidates(candidates: CandidateAssignment[]): void {
    let studentId = this.getActiveStudentId();
    let retained: CandidateAssignment[] = [];
    for (let existing of this.candidates) if (existing.studentId !== studentId) retained.push(existing);
    for (let candidate of candidates) {
      if (candidate.studentId === studentId && !this.hasAssignmentForCandidate(candidate.id)) retained.push(this.cloneCandidate(candidate));
    }
    this.candidates = retained;
    this.requestPersist();
  }

  updateCandidate(candidate: CandidateAssignment): boolean {
    let index = this.candidateIndex(candidate.id);
    if (index < 0 || candidate.studentId !== this.getActiveStudentId() ||
      this.candidates[index].studentId !== this.getActiveStudentId()) return false;
    this.candidates[index] = this.cloneCandidate(candidate);
    this.requestPersist();
    return true;
  }

  addCandidate(candidate: CandidateAssignment): boolean {
    if (candidate.studentId !== this.getActiveStudentId() || this.candidateIndex(candidate.id) >= 0 ||
      this.hasAssignmentForCandidate(candidate.id)) return false;
    this.candidates.push(this.cloneCandidate(candidate));
    this.requestPersist();
    return true;
  }

  updateCandidateTitle(candidateId: string, title: string): boolean {
    let index = this.candidateIndex(candidateId);
    if (index < 0 || this.candidates[index].studentId !== this.getActiveStudentId()) return false;
    this.candidates[index].title = title;
    this.candidates[index].instruction = title;
    this.requestPersist();
    return true;
  }

  removeCandidate(candidateId: string): boolean {
    let index = this.candidateIndex(candidateId);
    if (index < 0 || this.candidates[index].studentId !== this.getActiveStudentId()) return false;
    this.candidates.splice(index, 1);
    this.requestPersist();
    return true;
  }

  publishCandidates(): number {
    let studentId = this.getActiveStudentId();
    let published = 0;
    let retained: CandidateAssignment[] = [];
    for (let candidate of this.candidates) {
      if (candidate.studentId !== studentId) { retained.push(candidate); continue; }
      if (this.hasAssignmentForCandidate(candidate.id)) continue;
      let assignment: Assignment = {
        id: `a-published-${candidate.id}`,
        studentId: studentId,
        candidateId: candidate.id,
        assignmentType: AssignmentType.SCHOOL,
        subjectCode: this.subjectCode(candidate.subject),
        contentType: AssignmentContentType.NORMAL,
        subject: candidate.subject,
        title: candidate.title,
        instruction: candidate.instruction,
        textbookRef: candidate.textbookRef,
        dueAtEpochMs: 0,
        dueTimezone: 'Asia/Shanghai',
        dueText: candidate.dueText,
        status: AssignmentStatus.NOT_STARTED,
        expectedMinutes: candidate.expectedMinutes > 0 ? candidate.expectedMinutes : 20,
        startedAtEpochMs: 0,
        finishedAtEpochMs: 0,
        elapsedSeconds: 0,
        reviewNote: '',
        remoteVersion: 0,
        syncDirty: true,
        lastSyncedAtEpochMs: 0,
        resourceLabels: []
      };
      this.assignments.push(assignment);
      published++;
    }
    this.candidates = retained;
    this.requestPersist();
    return published;
  }

  transitionAssignment(assignmentId: string, to: AssignmentStatus): boolean {
    let index = this.assignmentIndex(assignmentId);
    if (index < 0 || this.assignments[index].studentId !== this.getActiveStudentId()) return false;
    let current = this.assignments[index].status;
    if (!AssignmentStateMachine.canTransition(current, to)) return false;
    let next = AssignmentStateMachine.transition(current, to);
    let now = Date.now();
    if (current !== AssignmentStatus.IN_PROGRESS && next === AssignmentStatus.IN_PROGRESS) {
      if (current !== AssignmentStatus.PAUSED) this.assignments[index].elapsedSeconds = 0;
      this.assignments[index].startedAtEpochMs = now;
      this.assignments[index].finishedAtEpochMs = 0;
    }
    if (current === AssignmentStatus.IN_PROGRESS && next !== AssignmentStatus.IN_PROGRESS) {
      if (this.assignments[index].startedAtEpochMs > 0) {
        this.assignments[index].elapsedSeconds += Math.max(0, Math.floor((now - this.assignments[index].startedAtEpochMs) / 1000));
      }
      this.assignments[index].startedAtEpochMs = 0;
      this.assignments[index].finishedAtEpochMs = next === AssignmentStatus.PAUSED ? 0 : now;
    }
    this.assignments[index].status = next;
    this.assignments[index].syncDirty = true;
    this.requestPersist();
    return true;
  }

  private pauseOtherAssignments(activeAssignmentId: string): void {
    let ids: string[] = [];
    for (let assignment of this.getAssignments()) {
      if (assignment.id !== activeAssignmentId && assignment.status === AssignmentStatus.IN_PROGRESS) ids.push(assignment.id);
    }
    for (let id of ids) this.transitionAssignment(id, AssignmentStatus.PAUSED);
  }

  startAssignment(assignmentId: string): boolean {
    let assignment = this.getAssignment(assignmentId);
    if (assignment === null) return false;
    if (assignment.status === AssignmentStatus.READY_TO_SUBMIT || assignment.status === AssignmentStatus.SUBMITTED ||
      assignment.status === AssignmentStatus.COMPLETED) return true;
    this.pauseOtherAssignments(assignmentId);
    if (assignment.status === AssignmentStatus.IN_PROGRESS) return true;
    return this.transitionAssignment(assignmentId, AssignmentStatus.IN_PROGRESS);
  }

  pauseAssignment(assignmentId: string): boolean {
    let assignment = this.getAssignment(assignmentId);
    if (assignment === null || assignment.status !== AssignmentStatus.IN_PROGRESS) return false;
    return this.transitionAssignment(assignmentId, AssignmentStatus.PAUSED);
  }

  markReadyToSubmit(assignmentId: string): boolean {
    return this.transitionAssignment(assignmentId, AssignmentStatus.READY_TO_SUBMIT);
  }

  submitImages(assignmentId: string, photoUris: string[], submittedAtText: string): boolean {
    if (photoUris.length === 0 || photoUris.length > 6) return false;
    if (!this.transitionAssignment(assignmentId, AssignmentStatus.SUBMITTED)) return false;
    let submission: Submission = { id: `submission-${this.submissionSequence}`, assignmentId: assignmentId,
      type: SubmissionType.IMAGE, photoUris: photoUris.slice(), fileLabel: `${photoUris.length} 张作业照片`,
      submittedAtText: submittedAtText };
    this.submissionSequence++;
    this.submissions.push(submission);
    this.requestPersist();
    return true;
  }

  reviewAssignment(assignmentId: string, completed: boolean, note: string): boolean {
    let assignment = this.getAssignment(assignmentId);
    if (assignment === null || assignment.status !== AssignmentStatus.SUBMITTED) return false;
    assignment.reviewNote = note.trim().substring(0, 1000);
    let target = completed ? AssignmentStatus.COMPLETED : AssignmentStatus.NEEDS_REWORK;
    return this.transitionAssignment(assignmentId, target);
  }

  getSubmissionsForAssignment(assignmentId: string): Submission[] {
    if (this.getAssignment(assignmentId) === null) return [];
    let result: Submission[] = [];
    for (let submission of this.submissions) if (submission.assignmentId === assignmentId) result.push(submission);
    return result;
  }

  getTodaySummary(): TodaySummary {
    let now = new Date();
    let completed = 0;
    let total = 0;
    let attention = 0;
    let undated = 0;
    for (let assignment of this.getAssignments()) {
      if (assignment.status === AssignmentStatus.OVERDUE || assignment.status === AssignmentStatus.NEEDS_REWORK) attention++;
      if (assignment.dueAtEpochMs <= 0) {
        if (assignment.status !== AssignmentStatus.COMPLETED) undated++;
        continue;
      }
      let due = new Date(assignment.dueAtEpochMs);
      let isToday = due.getFullYear() === now.getFullYear() && due.getMonth() === now.getMonth() && due.getDate() === now.getDate();
      if (!isToday) continue;
      total++;
      if (assignment.status === AssignmentStatus.COMPLETED) completed++;
    }
    let next = this.getNextAssignment();
    return { completed: completed, total: total, attention: attention, undated: undated,
      nextAssignmentId: next === null ? '' : next.id };
  }

  getDashboardSummary(): DashboardSummary {
    let summary: DashboardSummary = { completed: 0, inProgress: 0, paused: 0, notStarted: 0, overdue: 0,
      readyToSubmit: 0, submitted: 0, needsRework: 0 };
    for (let assignment of this.getAssignments()) {
      switch (assignment.status) {
        case AssignmentStatus.COMPLETED: summary.completed++; break;
        case AssignmentStatus.IN_PROGRESS: summary.inProgress++; break;
        case AssignmentStatus.PAUSED: summary.paused++; break;
        case AssignmentStatus.NOT_STARTED: summary.notStarted++; break;
        case AssignmentStatus.OVERDUE: summary.overdue++; break;
        case AssignmentStatus.READY_TO_SUBMIT: summary.readyToSubmit++; break;
        case AssignmentStatus.SUBMITTED: summary.submitted++; break;
        case AssignmentStatus.NEEDS_REWORK: summary.needsRework++; break;
      }
    }
    return summary;
  }

  getProgress(): AssignmentProgress[] {
    let result: AssignmentProgress[] = [];
    for (let assignment of this.getAssignments()) {
      result.push({ assignmentId: assignment.id, status: assignment.status,
        statusLabel: AssignmentStateMachine.label(assignment.status),
        submissionCount: this.getSubmissionsForAssignment(assignment.id).length });
    }
    return result;
  }
}
