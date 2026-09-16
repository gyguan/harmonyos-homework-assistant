import { AssignmentStatus } from './HomeworkModels';

export enum AssignmentTypeFilter {
  ALL = 'ALL',
  SCHOOL = 'SCHOOL',
  EXTRA = 'EXTRA'
}

export enum AssignmentDateFilter {
  ALL = 'ALL',
  TODAY = 'TODAY',
  TOMORROW = 'TOMORROW',
  THIS_WEEK = 'THIS_WEEK',
  UNDATED = 'UNDATED',
  CUSTOM = 'CUSTOM'
}

export interface AssignmentFilter {
  assignmentType: AssignmentTypeFilter;
  subjectCode: string;
  dateFilter: AssignmentDateFilter;
  fromEpochMs: number;
  toEpochMs: number;
  undatedOnly: boolean;
  statuses: AssignmentStatus[];
}

export class AssignmentFilters {
  static all(): AssignmentFilter {
    return {
      assignmentType: AssignmentTypeFilter.ALL,
      subjectCode: 'ALL',
      dateFilter: AssignmentDateFilter.ALL,
      fromEpochMs: 0,
      toEpochMs: 0,
      undatedOnly: false,
      statuses: []
    };
  }
}
