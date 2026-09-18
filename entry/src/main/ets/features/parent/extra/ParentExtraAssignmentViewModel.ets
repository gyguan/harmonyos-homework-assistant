import {
  Assignment,
  AssignmentContentType,
  AssignmentStatus,
  AssignmentType,
  StudentProfile,
  Subject
} from '../../../domain/model/HomeworkModels';
import { AssignmentRepository } from '../../../domain/port/AssignmentRepository';

export interface ExtraAssignmentDraft {
  category: Subject;
  title: string;
  instruction: string;
  dueAtEpochMs: number;
  dueText: string;
  expectedMinutes: number;
}

export class ParentExtraAssignmentViewModel {
  private readonly repository: AssignmentRepository;

  constructor(repository: AssignmentRepository) {
    this.repository = repository;
  }

  student(): StudentProfile {
    return this.repository.getActiveStudent();
  }

  async create(draft: ExtraAssignmentDraft): Promise<Assignment> {
    let student = this.student();
    let assignment: Assignment = {
      id: `a-extra-${student.id}-${Date.now()}-${Math.floor(Math.random() * 100000)}`,
      studentId: student.id,
      candidateId: '',
      assignmentType: AssignmentType.EXTRA,
      subjectCode: this.subjectCode(draft.category),
      contentType: AssignmentContentType.NORMAL,
      subject: draft.category,
      title: draft.title.trim(),
      instruction: draft.instruction.trim(),
      textbookRef: '',
      dueAtEpochMs: draft.dueAtEpochMs,
      dueTimezone: 'Asia/Shanghai',
      dueText: draft.dueText,
      status: AssignmentStatus.NOT_STARTED,
      expectedMinutes: draft.expectedMinutes,
      startedAtEpochMs: 0,
      finishedAtEpochMs: 0,
      elapsedSeconds: 0,
      reviewNote: '',
      remoteVersion: 0,
      syncDirty: false,
      lastSyncedAtEpochMs: 0,
      resourceLabels: []
    };
    return this.repository.create(assignment);
  }

  private subjectCode(category: Subject): string {
    if (category === Subject.CHINESE) return 'CHINESE';
    if (category === Subject.MATH) return 'MATH';
    if (category === Subject.ENGLISH) return 'ENGLISH';
    return 'OTHER';
  }
}
