export enum ScheduledAssignmentPlanType {
  MANUAL_ASSIGNMENT = 'MANUAL_ASSIGNMENT',
  VOICE_MATERIAL_AUTO = 'VOICE_MATERIAL_AUTO'
}

export enum ScheduledAssignmentScheduleType {
  ONCE = 'ONCE',
  DAILY = 'DAILY',
  WEEKDAYS = 'WEEKDAYS',
  WEEKLY = 'WEEKLY'
}

export enum ScheduledAssignmentStatus {
  ENABLED = 'ENABLED',
  PAUSED = 'PAUSED',
  ENDED = 'ENDED'
}

export enum ScheduledAssignmentDuePolicy {
  SAME_DAY_AT = 'SAME_DAY_AT',
  NEXT_DAY_AT = 'NEXT_DAY_AT',
  AFTER_MINUTES = 'AFTER_MINUTES',
  NONE = 'NONE'
}

export interface ScheduledAssignmentTemplate {
  assignmentType: string;
  subject: string;
  subjectCode: string;
  title: string;
  instruction: string;
  expectedMinutes: number;
  duePolicy: string;
  dueTime: string;
  dueOffsetMinutes: number;
}

export interface ScheduledAssignmentPlan {
  id: string;
  studentId: string;
  planType: string;
  name: string;
  scheduleType: string;
  timeOfDay: string;
  weekdays: string[];
  startDate: string;
  endDate: string;
  timezone: string;
  status: string;
  nextFireAtEpochMs: number;
  lastFireAtEpochMs: number;
  template: ScheduledAssignmentTemplate | null;
  version: number;
}

export interface ScheduledAssignmentRun {
  id: string;
  scheduledFireAtEpochMs: number;
  triggerSource: string;
  status: string;
  assignmentId: string;
  skipReason: string;
  errorMessage: string;
  retryCount: number;
  finishedAtEpochMs: number;
}

export interface ScheduledAssignmentPlanDraft {
  planType: string;
  name: string;
  scheduleType: string;
  timeOfDay: string;
  weekdays: string[];
  startDate: string;
  endDate: string;
  template: ScheduledAssignmentTemplate | null;
}
