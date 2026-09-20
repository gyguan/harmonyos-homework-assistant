import {
  AssignmentDateFilter,
  AssignmentFilter,
  AssignmentTypeFilter
} from '../model/AssignmentFilter';
import { AssignmentStatus } from '../model/HomeworkModels';
import { AssignmentDateRange, AssignmentEpochRange } from './AssignmentDateRange';

export class AssignmentFilterFactory {
  static forDay(subjectCode: string, dayEpochMs: number, statuses: AssignmentStatus[] = [],
    assignmentType: AssignmentTypeFilter = AssignmentTypeFilter.ALL): AssignmentFilter {
    let range = AssignmentDateRange.forDay(dayEpochMs);
    return AssignmentFilterFactory.fromRange(
      assignmentType, subjectCode, AssignmentDateFilter.CUSTOM, range, false, statuses);
  }

  static create(assignmentType: AssignmentTypeFilter, subjectCode: string,
    dateFilter: AssignmentDateFilter, statuses: AssignmentStatus[] = [],
    nowEpochMs: number = Date.now()): AssignmentFilter {
    let range: AssignmentEpochRange = { fromEpochMs: 0, toEpochMs: 0 };
    let undatedOnly = dateFilter === AssignmentDateFilter.UNDATED;
    if (dateFilter === AssignmentDateFilter.TODAY) range = AssignmentDateRange.today(nowEpochMs);
    else if (dateFilter === AssignmentDateFilter.TOMORROW) range = AssignmentDateRange.tomorrow(nowEpochMs);
    else if (dateFilter === AssignmentDateFilter.THIS_WEEK) range = AssignmentDateRange.thisWeek(nowEpochMs);
    return AssignmentFilterFactory.fromRange(
      assignmentType, subjectCode, dateFilter, range, undatedOnly, statuses);
  }

  private static fromRange(assignmentType: AssignmentTypeFilter, subjectCode: string,
    dateFilter: AssignmentDateFilter, range: AssignmentEpochRange, undatedOnly: boolean,
    statuses: AssignmentStatus[]): AssignmentFilter {
    return {
      assignmentType: assignmentType,
      subjectCode: subjectCode,
      dateFilter: dateFilter,
      fromEpochMs: range.fromEpochMs,
      toEpochMs: range.toEpochMs,
      undatedOnly: undatedOnly,
      statuses: statuses
    };
  }
}
