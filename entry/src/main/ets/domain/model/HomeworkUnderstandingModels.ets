import { CandidateAssignment, Subject } from './HomeworkModels';
import { ImportedMessage } from './ImportModels';

export enum HomeworkMessageClassification {
  HOMEWORK = 'HOMEWORK',
  HOMEWORK_REVISION = 'HOMEWORK_REVISION',
  PREPARATION = 'PREPARATION',
  NOTICE = 'NOTICE',
  CHAT = 'CHAT',
  UNKNOWN = 'UNKNOWN'
}

export enum TeacherResolutionStatus {
  RESOLVED = 'RESOLVED',
  UNKNOWN = 'UNKNOWN'
}

export interface TeacherDirectoryEntry {
  teacherId: string;
  displayName: string;
  aliases: string[];
  subject: Subject;
}

export interface HomeworkUnderstandingConfig {
  teacherDirectory: TeacherDirectoryEntry[];
}

export interface TeacherResolution {
  status: TeacherResolutionStatus;
  teacherId: string;
  displayName: string;
  subject: Subject | null;
}

export interface ClassifiedHomeworkMessage {
  message: ImportedMessage;
  teacher: TeacherResolution;
  classification: HomeworkMessageClassification;
  confidence: number;
}

export interface HomeworkTaskDraft {
  subject: Subject;
  title: string;
  instruction: string;
  dueText: string;
  expectedMinutes: number;
  classification: HomeworkMessageClassification;
  sourceMessageIds: string[];
  confidence: number;
}

export interface HomeworkUnderstandingResult {
  candidates: CandidateAssignment[];
  classifiedMessages: ClassifiedHomeworkMessage[];
  pendingReviewMessageIds: string[];
  warnings: string[];
}
