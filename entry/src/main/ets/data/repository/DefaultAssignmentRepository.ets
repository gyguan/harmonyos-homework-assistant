import { HomeworkSyncService } from '../../application/remote/HomeworkSyncService';
import { BackendSession } from '../../application/remote/BackendSession';
import { HomeworkRemoteApi } from '../../application/remote/HomeworkRemoteApi';
import { HomeworkStore } from '../HomeworkStore';
import { AssignmentFilter } from '../../domain/model/AssignmentFilter';
import { Assignment, StudentProfile, TodaySummary } from '../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../domain/port/AssignmentRepository';
import { AssignmentQuery } from '../../domain/service/AssignmentQuery';

export class DefaultAssignmentRepository implements AssignmentRepository {
  static readonly instance: DefaultAssignmentRepository = new DefaultAssignmentRepository();
  private remoteSummary: TodaySummary | null = null;

  private constructor() {}

  getActiveStudent(): StudentProfile {
    return HomeworkStore.instance.getStudent();
  }

  listCached(filter?: AssignmentFilter): Assignment[] {
    let items = HomeworkStore.instance.getAssignments().slice();
    if (filter === undefined) return AssignmentQuery.sort(items);
    return AssignmentQuery.filter(items, filter);
  }

  getCached(assignmentId: string): Assignment | null {
    return HomeworkStore.instance.getAssignment(assignmentId);
  }

  getCachedSummary(): TodaySummary {
    if (this.remoteSummary !== null) return this.remoteSummary;
    return HomeworkStore.instance.getTodaySummary();
  }

  async refresh(): Promise<boolean> {
    if (!BackendSession.instance.isConnected()) return false;
    let synced = await HomeworkSyncService.instance.syncActiveStudent();
    if (!synced) return false;
    try {
      this.remoteSummary = await HomeworkRemoteApi.instance.todaySummary(HomeworkStore.instance.getActiveStudentId());
    } catch {
      this.remoteSummary = null;
    }
    return true;
  }
}
