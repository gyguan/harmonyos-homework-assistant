export enum AssignmentStatus {
  NOT_STARTED = 'NOT_STARTED',
  IN_PROGRESS = 'IN_PROGRESS',
  PAUSED = 'PAUSED',
  READY_TO_SUBMIT = 'READY_TO_SUBMIT',
  SUBMITTED = 'SUBMITTED',
  COMPLETED = 'COMPLETED',
  NEEDS_REWORK = 'NEEDS_REWORK',
  OVERDUE = 'OVERDUE'
}

export enum AssignmentType {
  SCHOOL = 'SCHOOL',
  EXTRA = 'EXTRA'
}

export enum AssignmentContentType {
  NORMAL = 'NORMAL',
  AUDIO_IMAGE = 'AUDIO_IMAGE'
}

export enum AssignmentBacking {
  LOCAL_SEED = 'LOCAL_SEED',
  REMOTE = 'REMOTE'
}

export enum AssignmentResourceType {
  AUDIO = 'AUDIO',
  IMAGE = 'IMAGE'
}

export enum Subject {
  CHINESE = '语文',
  MATH = '数学',
  ENGLISH = '英语',
  READING = '阅读',
  READ_ALOUD = '朗读',
  SPORTS = '体育',
  PRACTICE = '实践',
  INTEREST = '兴趣',
  OTHER = '其他'
}

export enum SubmissionType {
  IMAGE = 'IMAGE'
}

export enum HomeworkImportSourceKind {
  TEXT = 'TEXT',
  IMAGE = 'IMAGE',
  FILE = 'FILE',
  SHARE = 'SHARE'
}

export interface AssignmentResource {
  id: string;
  resourceType: AssignmentResourceType;
  originalName: string;
  contentType: string;
  sizeBytes: number;
  sortOrder: number;
  durationMs: number;
  downloadPath: string;
}

export interface StudentProfile {
  id: string;
  name: string;
  grade: string;
  className: string;
  semester: string;
  textbookSummary: string;
}

export interface AppSettings {
  students: StudentProfile[];
  activeStudentId: string;
  parentAccessCode: string;
  tutorGuidanceFirst: boolean;
  directAnswerAllowed: boolean;
}

export interface RawHomeworkImport {
  id: string;
  studentId: string;
  sourceKind: HomeworkImportSourceKind;
  sourceLabel: string;
  resourceUri: string;
  rawText: string;
}

export interface SourceEvidence {
  sourceLabel: string;
  excerpt: string;
  batchId?: string;
  sourceType?: string;
  sourceMessageIds?: string[];
  rawText?: string;
  imageRef?: string;
  capturedAtEpochMs?: number;
}

export interface CandidateAssignment {
  id: string;
  studentId: string;
  subject: Subject;
  title: string;
  instruction: string;
  textbookRef: string;
  dueText: string;
  expectedMinutes: number;
  sourceEvidence: SourceEvidence;
  confidence: number;
}

export interface Assignment {
  id: string;
  studentId: string;
  candidateId: string;
  backing: AssignmentBacking;
  assignmentType: AssignmentType;
  subjectCode: string;
  contentType?: AssignmentContentType;
  subject: Subject;
  title: string;
  instruction: string;
  textbookRef: string;
  dueAtEpochMs: number;
  dueTimezone: string;
  dueText: string;
  dueDateKey?: string;
  status: AssignmentStatus;
  expectedMinutes: number;
  startedAtEpochMs: number;
  finishedAtEpochMs: number;
  elapsedSeconds: number;
  reviewNote: string;
  remoteVersion: number;
  syncDirty: boolean;
  lastSyncedAtEpochMs: number;
  resourceLabels: string[];
}

export interface Submission {
  id: string;
  assignmentId: string;
  type: SubmissionType;
  photoUris: string[];
  fileLabel: string;
  submittedAtText: string;
}

export interface TutorSession {
  id: string;
  studentId: string;
  assignmentId: string;
  startedAtText: string;
  questionCount: number;
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
  attention: number;
  undated: number;
  nextAssignmentId: string;
}

export interface DashboardSummary {
  completed: number;
  inProgress: number;
  paused: number;
  notStarted: number;
  overdue: number;
  readyToSubmit: number;
  submitted: number;
  needsRework: number;
}
