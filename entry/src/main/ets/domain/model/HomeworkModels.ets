export enum AssignmentStatus {
  NOT_STARTED = 'NOT_STARTED',
  IN_PROGRESS = 'IN_PROGRESS',
  READY_TO_SUBMIT = 'READY_TO_SUBMIT',
  SUBMITTED = 'SUBMITTED',
  COMPLETED = 'COMPLETED',
  NEEDS_REWORK = 'NEEDS_REWORK',
  OVERDUE = 'OVERDUE'
}

export enum Subject {
  CHINESE = '语文',
  MATH = '数学',
  ENGLISH = '英语'
}

export enum SubmissionType {
  MOCK_IMAGE = 'MOCK_IMAGE'
}

export enum HomeworkImportSourceKind {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE',
  FILE = 'FILE',
  SHARE = 'SHARE'
}

export interface RawHomeworkImport {
  id: string;
  familyId: string;
  sourceKind: HomeworkImportSourceKind;
  sourceLabel: string;
  resourceUri: string;
  rawText: string;
}

export interface SourceEvidence {
  sourceLabel: string;
  excerpt: string;
}

export interface CandidateAssignment {
  id: string;
  familyId: string;
  studentId: string;
  subject: Subject;
  title: string;
  instruction: string;
  textbookRef: string;
  dueText: string;
  sourceEvidence: SourceEvidence;
  confidence: number;
}

export interface Assignment {
  id: string;
  familyId: string;
  studentId: string;
  candidateId: string;
  subject: Subject;
  title: string;
  instruction: string;
  textbookRef: string;
  dueText: string;
  status: AssignmentStatus;
  resourceLabels: string[];
}

export interface Submission {
  id: string;
  assignmentId: string;
  type: SubmissionType;
  fileLabel: string;
  submittedAtText: string;
}

export interface AssignmentProgress {
  assignmentId: string;
  status: AssignmentStatus;
  statusLabel: string;
  submissionCount: number;
}

export interface TodaySummary {
  completed: number;
  total: number;
  nextAssignmentId: string;
}

export interface DashboardSummary {
  completed: number;
  inProgress: number;
  notStarted: number;
  overdue: number;
  readyToSubmit: number;
  submitted: number;
  needsRework: number;
}
