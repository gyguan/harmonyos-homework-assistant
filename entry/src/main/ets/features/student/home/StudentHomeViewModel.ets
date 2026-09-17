import {
  Assignment,
  AssignmentStatus,
  StudentProfile,
  Subject,
  TodaySummary
} from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';

export class StudentHomeSubjectGroup {
  key: string;
  subject: Subject;
  items: Assignment[];

  constructor(key: string, subject: Subject, items: Assignment[]) {
    this.key = key;
    this.subject = subject;
    this.items = items;
  }
}

export class StudentHomeViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository) {
    this.repository = repository;
  }

  student(): StudentProfile {
    return this.repository.getActiveStudent();
  }

  summary(): TodaySummary {
    return this.repository.getCachedSummary();
  }

  assignments(): Assignment[] {
    return this.repository.listCached();
  }

  todayActionableAssignments(): Assignment[] {
    let result: Assignment[] = [];
    for (let item of this.assignments()) {
      if (!StudentHomeViewModel.isToday(item)) continue;
      if (!StudentHomeViewModel.isActionable(item.status)) continue;
      StudentHomeViewModel.insertByPriority(result, item);
    }
    return result;
  }

  todaySubjectGroups(): StudentHomeSubjectGroup[] {
    let assignments = this.todayActionableAssignments();
    let groups: StudentHomeSubjectGroup[] = [];
    let subjects: Subject[] = [
      Subject.CHINESE,
      Subject.MATH,
      Subject.ENGLISH,
      Subject.READING,
      Subject.READ_ALOUD,
      Subject.SPORTS,
      Subject.PRACTICE,
      Subject.INTEREST,
      Subject.OTHER
    ];

    for (let subject of subjects) {
      let items: Assignment[] = [];
      for (let assignment of assignments) {
        if (assignment.subject === subject) items.push(assignment);
      }
      if (items.length > 0) groups.push(new StudentHomeSubjectGroup(subject, subject, items));
    }
    return groups;
  }

  todaySubjectCount(): number {
    return this.todaySubjectGroups().length;
  }

  todayPendingCount(): number {
    return this.todayActionableAssignments().length;
  }

  todayExpectedMinutes(): number {
    let total = 0;
    for (let item of this.todayActionableAssignments()) {
      if (item.expectedMinutes > 0) total += item.expectedMinutes;
    }
    return total;
  }

  nextAssignment(): Assignment | null {
    let items = this.todayActionableAssignments();
    if (items.length === 0) return null;

    let summary = this.summary();
    if (summary.nextAssignmentId.length > 0) {
      for (let item of items) {
        if (item.id === summary.nextAssignmentId) return item;
      }
    }
    return items[0];
  }

  attentionCount(): number {
    let count = 0;
    for (let item of this.todayActionableAssignments()) {
      if (item.status === AssignmentStatus.OVERDUE || item.status === AssignmentStatus.NEEDS_REWORK) count++;
    }
    return count;
  }

  dateLabel(): string {
    let now = new Date();
    let weekday: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `今天 · ${now.getMonth() + 1}月${now.getDate()}日 ${weekday[now.getDay()]}`;
  }

  async refresh(): Promise<boolean> {
    return this.repository.refresh();
  }

  private static isToday(item: Assignment): boolean {
    if (item.dueAtEpochMs <= 0) return false;
    let due = new Date(item.dueAtEpochMs);
    let now = new Date();
    return due.getFullYear() === now.getFullYear() &&
      due.getMonth() === now.getMonth() &&
      due.getDate() === now.getDate();
  }

  private static isActionable(status: AssignmentStatus): boolean {
    return StudentHomeViewModel.priority(status) < 100;
  }

  private static priority(status: AssignmentStatus): number {
    if (status === AssignmentStatus.IN_PROGRESS) return 0;
    if (status === AssignmentStatus.PAUSED) return 1;
    if (status === AssignmentStatus.NEEDS_REWORK) return 2;
    if (status === AssignmentStatus.OVERDUE) return 3;
    if (status === AssignmentStatus.NOT_STARTED) return 4;
    if (status === AssignmentStatus.READY_TO_SUBMIT) return 5;
    return 100;
  }

  private static insertByPriority(result: Assignment[], item: Assignment): void {
    for (let index = 0; index < result.length; index++) {
      if (StudentHomeViewModel.isBetter(item, result[index])) {
        result.splice(index, 0, item);
        return;
      }
    }
    result.push(item);
  }

  private static isBetter(candidate: Assignment, current: Assignment): boolean {
    let candidatePriority = StudentHomeViewModel.priority(candidate.status);
    let currentPriority = StudentHomeViewModel.priority(current.status);
    if (candidatePriority !== currentPriority) return candidatePriority < currentPriority;
    if (candidate.dueAtEpochMs !== current.dueAtEpochMs) return candidate.dueAtEpochMs < current.dueAtEpochMs;
    return candidate.id < current.id;
  }
}
