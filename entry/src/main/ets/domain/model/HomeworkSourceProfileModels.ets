import { Subject } from './HomeworkModels';

export interface HomeworkSourceTeacherAlias {
  displayName: string;
  aliases: string[];
  subject: Subject;
}

export interface HomeworkSourceProfile {
  id: string;
  name: string;
  groupTitle: string;
  studentId: string;
  teacherAliases: HomeworkSourceTeacherAlias[];
  defaultStartMinuteOfDay: number;
  enabled: boolean;
  createdAtEpochMs: number;
  updatedAtEpochMs: number;
  lastUsedAtEpochMs: number;
}

export interface HomeworkSourceProfileSnapshot {
  schemaVersion: number;
  profiles: HomeworkSourceProfile[];
}

export enum SourceGroupValidationStatus {
  MATCHED = 'MATCHED',
  MISMATCH = 'MISMATCH',
  UNRECOGNIZED = 'UNRECOGNIZED',
  CONFLICT = 'CONFLICT'
}
