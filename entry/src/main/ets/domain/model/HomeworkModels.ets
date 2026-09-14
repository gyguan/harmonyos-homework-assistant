export enum AssignmentStatus {
  NOT_STARTED = 'NOT_STARTED',
  IN_PROGRESS = 'IN_PROGRESS',
  SUBMITTED = 'SUBMITTED',
  COMPLETED = 'COMPLETED',
  OVERDUE = 'OVERDUE'
}

export enum Subject {
  CHINESE = '语文',
  MATH = '数学',
  ENGLISH = '英语'
}

export interface Assignment {
  id: string;
  subject: Subject;
  title: string;
  instruction: string;
  textbookRef: string;
  dueText: string;
  status: AssignmentStatus;
  resourceLabels: string[];
}

export interface TodaySummary {
  completed: number;
  total: number;
  nextAssignmentId: string;
}

export interface CandidateAssignment {
  id: string;
  subject: Subject;
  title: string;
  dueText: string;
  sourceEvidence: string;
  confidence: number;
}

export interface DashboardSummary {
  completed: number;
  inProgress: number;
  notStarted: number;
  overdue: number;
}
